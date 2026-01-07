"""
This module is an all-in-one duplication of the dependency_detective module and all its dependencies.
This build can simplify the installation of the module. No need to configure python path anymore
"""
import argparse
import configparser
import json
import os
import sys
from subprocess import CalledProcessError
from typing import List, Dict, Set
from johnnydep import JohnnyDist
from johnnydep.logs import configure_logging
from structlog import get_logger

configure_logging(1)

logger = get_logger(__name__)

# bandersnatch conf file config
SECTION_NAME = "allowlist"
KEY_NAME = "packages"
PACKAGE_STR_SEP = "\n"

TOOL_DESCRIPTION = """This tool takes a bandersnatch conf file, read the white list package, then complete the
list with all required dependent packages, and update the white list with the extra packages. If no new packages 
need to be added, do nothing. If an output file path is provided, the generated conf file will be written inside 
 the provided config file path, otherwise it will overwrite the input config file"""

# Base URL of the Python Package Index (default https://pypi.org/simple). This should point to a repository compliant
# with PEP 503 (the simple repository API) or a local directory laid out in the same format.
REPO_URL = "https://pypi.org/simple"
# define an extra repo
EXTRA_REPO_URL = "https://pypi.org/simple"

# if you want to use another python binary, set the python path below
CUSTOM_PY_ENV = None
# Specify if the program continue to progress or stop
IGNORE_ERRORS = False
# Define the output fields of the package information.
OUTPUT_FIELDS = ["name", "required_by", "summary"]
# Define the output format of JohnnyDist, possible values are json,yaml,python,toml. Here we fixed it to json
OUTPUT_FORMAT = "json"
# search dependencies recursively or not. By default, we set it to True
SEARCH_RECURSIVE = True



def get_package_dependencies(package_name: str) -> List[Dict]:
    """
    This function takes a package name, then returns a List of dict which represent the dependent package details.
    By default, the dictionary has three key name, required-by, summary. If no dependency is found, return
    an empty set
    :param package_name:
    :type package_name:
    :return:
    :rtype:
    """
    if package_name:
        try:
            dist = JohnnyDist(
                package_name,
                index_url=REPO_URL,
                env=CUSTOM_PY_ENV,
                extra_index_url=EXTRA_REPO_URL,
                ignore_errors=IGNORE_ERRORS,
            )
            raw_result = dist.serialise(
                fields=OUTPUT_FIELDS,
                format=OUTPUT_FORMAT,
                recurse=SEARCH_RECURSIVE,
            )
        except CalledProcessError:
            logger.error(f"Cannot find a corresponding package by using the given package name {package_name}")
            raise ValueError(f"Cannot find a corresponding package by using the given package name {package_name}")
        if raw_result:
            return json.loads(raw_result)

        else:
            return []
    else:
        # if the package name is empty, raise value error
        logger.error("The package name can't be empty")
        raise ValueError("The package name can't be empty")


def get_package_dependency_names(package_name: str) -> Set[str]:
    """
    This function takes a package name, then returns a set of dependent package name. If no dependency is found, return
    an empty set
    :param package_name:
    :type package_name:
    :return:
    :rtype:
    """
    raw_result = get_package_dependencies(package_name)
    if raw_result:
        dep_name_set: Set[str] = set()
        for item in raw_result:
            dep_name_set.add(item['name'])
        return dep_name_set
    else:
        return set()


def build_packages_dependencies_list(package_names: Set[str]) -> List[Dict]:
    """
    This function takes a set of package names, then returns a set of dict which represent the dependent package
    details. By default, the dictionary has three key name, required-by, summary. If no dependency is found, return
    an empty set
    :param package_names:
    :type package_names:
    :return:
    :rtype:
    """
    package_name_key = "name"
    full_list = []
    if not package_names or len(package_names) == 0:
        logger.error("The package name list is empty. Terminating the proces")
        sys.exit(1)
    for package_name in package_names:
        partial_list: List[Dict] = get_package_dependencies(package_name)
        # convert dict to tuple and store it in a set to remove duplicated packages
        for package_dict in partial_list:
            # if the package is already in the full list, do nothing. If not add the package to the list
            if not check_value_in_list_of_dicts(full_list, package_name_key, package_dict[package_name_key]):
                full_list.append(package_dict)
    return full_list


def build_packages_dependency_names_list(package_names: Set[str]) -> List[str]:
    """
    This function takes a set of package names, then returns a list of the dependent package names
    If no dependency is found, returns an empty list. The names in the list is sorted
    :param package_names:
    :type package_names:
    :return:
    :rtype:
    """
    full_list: Set[str] = set()
    if not package_names or len(package_names) == 0:
        print("The package name list is empty. Terminating the proces")
        sys.exit(1)
    for package_name in package_names:
        partial_list: Set[str] = get_package_dependency_names(package_name)
        full_list = full_list.union(partial_list)
    return sorted(full_list)


def check_value_in_list_of_dicts(list_of_dicts: List[dict], key: str, value: str) -> bool:
    """
    This function check if a list of dictionary contains a given key value pair. If yes, return true, else return false
    :param list_of_dicts: The input list
    :type list_of_dicts: List[dict]
    :param key: key which we search inside the dictionary
    :type key: str
    :param value: value which we search inside the dictionary
    :type value: str
    :return:
    :rtype: bool
    """
    for d in list_of_dicts:
        if key in d and d[key] == value:
            return True
    return False

def check_conf(conf_path: str, output_path=None):
    # check if the conf file exist, if not stop all
    if not os.path.exists(conf_path):
        logger.error(f"The given file path {conf_path} does not exist")
        raise ValueError(f"The given file path {conf_path} is not valid")
    config = configparser.ConfigParser()
    config.read(conf_path)
    # step 1: get current packages
    # this returns a string of package names seperated by \n
    try:
        current_packages_str = config.get(SECTION_NAME, KEY_NAME)
    except configparser.NoSectionError:
        logger.error(f"The given config file does not contain the section:{SECTION_NAME} or key:{KEY_NAME}")
        raise ValueError(f"The given config file does not contain the section:{SECTION_NAME} or key:{KEY_NAME}")
    # convert the string to list
    current_package_name_list = convert_package_str_to_list(current_packages_str)

    # step 2: build the complete list with dependencies
    full_package_name_list = build_packages_dependency_names_list(set(current_package_name_list))
    # if the current package name list is already complete. Stop the program
    if full_package_name_list == current_package_name_list:
        logger.info("The package name list in the current config file is complete.")
        return
    else:
        # step 3: if the config file need to be updated, write the complete list to new config file
        full_package_str = convert_package_list_to_str(full_package_name_list)
        config.set(SECTION_NAME, KEY_NAME, full_package_str)
        if not output_path:
            output_path = conf_path
        with open(output_path, "w") as output_file:
            config.write(output_file)


def convert_package_str_to_list(package_names: str) -> List[str]:
    """
    This function takes the string read from the bandersnatch conf, and convert it to a list of package names
    :param package_names:
    :type package_names: str
    :return:
    :rtype:
    """
    return [package.strip() for package in package_names.strip().split(PACKAGE_STR_SEP)]


def convert_package_list_to_str(package_list: List[str]) -> str:
    """
    This function convert a list of package names to a string which is compatible with the format required by
    bandersnatch
    :param package_list:
    :type package_list:
    :return:
    :rtype:
    """
    return f'{PACKAGE_STR_SEP}{PACKAGE_STR_SEP.join(package_list)}'


def main():
    parser = argparse.ArgumentParser(description=TOOL_DESCRIPTION)
    parser.add_argument("conf_file_path", help="Specify the path of the bandersnatch conf file")
    parser.add_argument("-o", "--output", help="Specify the path of the generated conf file. If empty, the output will "
                                               "overwrite the provided input bandersnatch conf file")
    args = parser.parse_args()
    conf_file_path = args.conf_file_path
    output = args.output
    logger.info(f"Start the package dependencies check")
    if output:
        logger.info(f"The generated configuration will be written in {output}")
        check_conf(conf_file_path, output_path=output)
    else:
        logger.info(f"No output file path is provide, the generated configuration will overwrite the {conf_file_path}")
        check_conf(conf_file_path)
    logger.info("The package dependencies check is terminated with success")


if __name__ == "__main__":
    main()