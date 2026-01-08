# Cron job 


**Cron** is a time-based job scheduling daemon found in Unix-like operating systems, including Linux distributions. Cron runs in the background and operations scheduled with cron, referred to as "cron jobs", are executed automatically, making cron useful for automating maintenance-related tasks.

## Installation 


```shell
# Debian
sudo apt-get install cron

# centos
sudo yum install cronie

# gentoo
sudo emerge -av sys-process/cronie
```

## Understanding How Cron Works 

Cron jobs are recorded and managed in a special file known as a crontab. Each user profile on the system can have their own crontab where they can schedule jobs, which is stored under /var/spool/cron/crontabs/.

To schedule a job, open up your crontab for editing and add a task written in the form of a cron expression. The syntax for cron expressions can be broken down into two elements: the schedule and the command to run.

The command can be virtually any command you would normally run on the command line. The schedule component of the syntax is broken down into 5 different fields, which are written in the following order:

```text
# Example of job definition:
# .---------------- minute (0 - 59)
# |  .------------- hour (0 - 23)
# |  |  .---------- day of month (1 - 31)
# |  |  |  .------- month (1 - 12) OR jan,feb,mar,apr ...
# |  |  |  |  .---- day of week (0 - 6) (Sunday=0 or 7) OR sun,mon,tue,wed,thu,fri,sat
# |  |  |  |  |
# *  *  *  *  *  user command to be executed

mm hh jj MMM JJJ [user] task > log
```

- **mm**: 1st position, minute (0 - 59)
-  **hh**: hour (0 - 23).
- **jj**: day of month (1 - 31).
- **MMM**: mmonth (1 - 12) OR jan,feb,mar,apr ...
- **JJJ**: day of the week (0 - 6) (Sunday=0 or 7) OR sun,mon,tue,wed,thu,fri,sat
- **user (optional)**: uid of user who runs the task (with user right)
- **task**: command to be executed.
- **log (optional)**: redirect the task output to a log file. if no file is specified, a mail will be sent to the user locally.

> Each line you add in the crontab will be transformed into a cronjob

## Configuration 

### Managing Cron Job Output 

Because cron jobs are executed in the background, it isn’t always apparent that they’ve run successfully. So redirecting the output of cron jobs to help you track that they’ve been executed successfully.


#### send mail 

If you have a mail transfer agent, such as `Sendmail`, installed and properly configured on your server, you can set it up in your crontab

```shell
# open your crontab editor
crontab -e

# add below lines
MAILTO="example@digitalocean.com"
SHELL=/bin/bash
HOME=/

* * * * * echo 'Run this command every minute'
```

#### Redirect to a log file 

To append a scheduled command’s output to a log file, add >> to the end of the command followed by the name and location of a log file of your choosing, like this:

```shell
# below command print data to std output, and std output is redirected to the given log file 
* * * * * echo ‘Run this command every minute’ >> /directory/path/file.log

# if we want to direct the error to the log file, we can use the below line
# 2 indicates standard error, >&1 means redirect std error to std out,
# as std out is redirect to log, so all std error will be in log file too. 
* * * * * echo ‘Run this command every minute’ >> /directory/path/file.log  2>&1
```

### Access control 


You can manage which users can use the crontab command with the **cron.allow** and **cron.deny** files, both of which are stored in the **/etc/** directory. If the cron.deny file exists, any user listed in it will be barred from editing their crontab. If cron.allow exists, only users listed in it will be able to edit their crontabs. If both files exist and the same user is listed in each, the cron.allow file will override cron.deny and the user will be able to edit their crontab.

For example, to `deny access to all users and then give access to the user ishmael`, you could use the following command sequence:

```shell
sudo echo ALL >>/etc/cron.deny
sudo echo ishmael >>/etc/cron.allow
```

> Legacy job is not impacted by the modification of the two files. For example, if a user has a crontab and some corn job running, if we delete this user's uid from `/etc/cron.allow`, The already running job will continue. To stop all **You need to delete the crontab of this user which is located at /var/spool/cron/crontabs**


## Use crontab 

Below are some useful commands for cron

```shell
# list the existing cron jobs
crontab -l

# Editing the cron jobs
# this command will open a text file editor
# each line you add will be transformed into a cronjob
crontab -e

```

## Cron job scheduler syntaxes 

In each column, you can use numbers and acronyms such as `JAN-DEC` and `SUN-SAT`. There are also a few special characters you can include in the schedule component of a cron expression to streamline scheduling tasks:

  *  `*`: In cron expressions, an asterisk is a wildcard variable that represents “all.” Thus, a task scheduled with * * * * * ... will run every minute of every hour of every day of every month.
  * `,`: Commas break up scheduling values to form a list. If you want to have a task run at the beginning and middle of every hour, rather than writing out two separate tasks (e.g., 0 * * * * ... and 30 * * * * ...), you could achieve the same functionality with one (0,30 * * * * ...).
  * `-`: A hyphen represents a range of values in the schedule field. Instead of having 30 separate scheduled tasks for a command you want to run for the first 30 minutes of every hour (as in 0 * * * * ..., 1 * * * * ..., 2 * * * * ..., and so on), instead, you could schedule it as 0-29 * * * * ....
  * `/`: You can use a forward slash with an asterisk to express a step value. For example, instead of writing out eight separate cron tasks to run a command every three hours (as in, 0 0 * * * ..., 0 3 * * * ..., 0 6 * * * ..., and so on), you could schedule it to run like this: 0 */3 * * * ....

For each time column, we can use the three below expressions:
  * start-end: This operator means the time range is from start to end. For example, if we put 2-4 in the `JJJ` column, the task will be executed every Tuesday, Wednesday, and Thursday. If we put 7-12 in the `MMM` column, the job will be executed every last 6 months of the year.
  * start/step: This operator means every step from the start. For example, if 2/15 is in the `mm` column, this task will be executed every 15 mins starting at the 2nd min after every hour. if */8 is in the `hh` column, this task will be executed every 8 hours of every day.
  * time1,time2,time3,...: This operator means run task at time1, time2 and time3, etc. 

### Some examples 

Here are some more examples of how to use cron’s scheduling component:

  - * * * * * - Run the command every minute.
  - 12 * * * * - Run the command 12 minutes after every hour.
  - 0,15,30,45 * * * * - Run the command every 15 minutes.
  - */15 * * * * - Run the command every 15 minutes.
  - 0 4 * * * - Run the command every day at 4:00 AM.
  - 0 4 * * 2-4 - Run the command every Tuesday, Wednesday, and Thursday at 4:00 AM.
  - 20,40 */8 * 7-12 * - Run the command on the 20th and 40th minute of every 8th hour every day of the last 6 months of the year.

### Special Syntax 

There are also several shorthand commands you can use in your crontab file to help streamline job scheduling. They are essentially shortcuts for the equivalent numeric schedule specified:

  * **@hourly** : 0 * * * *
  * **@daily** : 0 0 * * *
  * **@weekly** : 0 0 * * 0
  * **@monthly**: 0 0 1 * *
  * **@yearly**: 0 0 1 1 *
  * @reboot: each reboot

For example, if you add the below line into the crontab

```
# this will be executed after each reboot
@reboot echo "System start-up"
``` 

## Predefined cron scheduler

By default, cron already have 4 predefine

- hourly
- daily
- weekly
- monthly

You can get the detail of these scheduler with the below command

```shell
cat /etc/crontab

# output example
# /etc/crontab: system-wide crontab
# Unlike any other crontab you don't have to run the `crontab'
# command to install the new version when you edit this file
# and files in /etc/cron.d. These files also have username fields,
# that none of the other crontabs do.

SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Example of job definition:
# .---------------- minute (0 - 59)
# |  .------------- hour (0 - 23)
# |  |  .---------- day of month (1 - 31)
# |  |  |  .------- month (1 - 12) OR jan,feb,mar,apr ...
# |  |  |  |  .---- day of week (0 - 6) (Sunday=0 or 7) OR sun,mon,tue,wed,thu,fri,sat
# |  |  |  |  |
# *  *  *  *  * user-name command to be executed
17 *    * * *   root    cd / && run-parts --report /etc/cron.hourly
25 6    * * *   root    test -x /usr/sbin/anacron || ( cd / && run-parts --report /etc/cron.daily )
47 6    * * 7   root    test -x /usr/sbin/anacron || ( cd / && run-parts --report /etc/cron.weekly )
52 6    1 * *   root    test -x /usr/sbin/anacron || ( cd / && run-parts --report /etc/cron.monthly )
```

For example, the weekly scheduler will be executed at 6:47 am of every sunday (0 or 7).

### script directory

- /etc/cron.d/ :	Put all scripts here and call them from /etc/crontab file.
- /etc/cron.daily/:	Run all scripts once a day
- /etc/cron.hourly/:	Run all scripts once an hour
- /etc/cron.monthly/:	Run all scripts once a month
- /etc/cron.weekly/:	Run all scripts once a week

> Note you need to remove all file extentions such as `.sh`

### test your cronjob

Add a shell or bash script (e.g. aptly_build_release) into directory `cron.daily`, then run the below command 

```shell
# add your script 
sudo vim /etc/cron.daily/aptly_build_release

# add execution right
sudo chmod a+x /etc/cron.daily/aptly_build_release

# list available cron job
run-parts --test /etc/cron.daily

# if you see below line, it means your script will be executed daily
/etc/cron.daily//aptly_build_release
```

> All script in cron daily/weekly/monthly will be run with user root. If your script need to be run with specific user privilege, you need to use below command 

```bash
if [ "$(id -u)" -eq 0 ]; then
            exec sudo -u <uid> <command> <args>;
fi
```

