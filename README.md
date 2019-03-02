scripts-common version 2.0
====
[![Codacy Badge](https://api.codacy.com/project/badge/Grade/f61fd4ae962a42dd93cca6de29ac8c1d)](https://www.codacy.com/app/bertrand-benoit/scripts-common?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=bertrand-benoit/scripts-common&amp;utm_campaign=Badge_Grade)

This is a free common utilities/tool-box for GNU/Bash scripts, you can use for your own scripts.

It provides lots of features, using mainly GNU/Bash built-in tools, like:
-   logger (writeMessage, info, warning, error), with timestamp and category
-   environment check and utilities (locale, isRoot, LSB)
-   path check and management (data file, directory, executable)
-   configuration file management (local configuration file, global configuration file, check and set configuration)
-   version check (isVersionGreater)
-   start/stop/up time
-   pattern matching (including isNumber, isDate ...)
-   extract lines from a file (from N, or between N and P)
-   PID file management
-   daemon start/pause/stop
-   Third party PATH management feature (Java, Ant ...)

Context
--
Around 2000, I started writing it for my personal needs, creating lots of scripts at home and at work.

In 2010, I created [Hemera Intelligent System](http://hemerais.bertrand-benoit.net/doc/index.php?title=Hemera:QuickStart) ([Github repository](https://github.com/bertrand-benoit/hemerais)), in which I factorized all my utilities, and developed more robust version.

In 2019, I extracted the Hemera's utilities part, and enhanced it to get it generic, to share it with everyone.


Usage
====

In all the following methods, you just need to source the utilities file.
```
source <path to define>/scripts-common/utilities.sh
```

Method 1 - Git submodule
--
You can add this project as [submodule](https://git-scm.com/book/en/v2/Git-Tools-Submodules) of your own Git repository.


Method 2 - Clone repository close to yours
--
Clone this repository in the parent directory of your own repository.

You can then source the utilities this way:
```
currentDir="$( dirname "$( which "$0" )" )"
source "$( dirname "$currentDir" )/scripts-common/utilities.sh"
```


Method 3 - Clone repository anywhere
--
Clone this repository where you want, and define a variable in your `~/.bashrc` file, for instance:
```
export UTILITIES_PATH=/complete/path/to/scripts-common/utilities.sh
```

Then, in your script, you just need to use this variable:
```
source "$UTILITIES_PATH"
```


Environment
====
There are some optional variables you can define before sourcing the `utilities.sh`, to tune the system to your needs.

*   **ROOT_DIR**           `<path>`  root directory to consider when performing various check
*   **TMP_DIR**            `<path>`  temporary directory where various dump files will be created
*   **PID_DIR**            `<path>`  directory where PID files will be created to manage daemon feature
*   **CONFIG_FILE**        `<path>`  path of configuration file to consider
*   **GLOBAL_CONFIG_FILE** `<path>`  path of GLOBAL configuration file to consider (configuration element will be checked in this one, if NOT found in the configuration file)
*   **DEBUG_UTILITIES**              `0|1`  activate debug message (not recommended in production)
*   **VERBOSE**                      `0|1`  activate info/debug message
*   **CATEGORY**                 `<string>` the category which prepends all messages
*   **LOG_CONSOLE_OFF**              `0|1`  disable message output on console
*   **LOG_FILE**                   `<path>` path of the log file
*   **LOG_FILE_APPEND_MODE**         `0|1`  activate append mode, instead of override one
*   **MODE_CHECK_CONFIG**   `0|1`  check ALL configuration and then quit (useful to check all the configuration you want, +/- like a dry run)


N.B.: when using `checkAndSetConfig` function, you can get back the corresponding configuration in **LAST_READ_CONFIG** variable (if it has NOT been found, it is set to *$CONFIG_NOT_FOUND*).


Information
====
Don't hesitate to contribute or to contact me if you want to improve the script.

[Bertrand BENOIT](mailto:contact@bertrand-benoit.net)
