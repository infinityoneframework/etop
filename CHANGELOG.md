# Etop Changelog


## 0.5.2 (2020-10-26)

### Features

* Add monitor with callback feature
  * Register a monitor with
    * field to monitor
    * threshold
    * callback when that threshold is exceed twice in a row.
* Toggle reporting feature

## 0.5.1 (2020-10-24)

### Features

* Add sort option


## 0.5.0 (2020-10-23)

### Bug fixes

* Fix dead process exception
* Fix CPU utilization

### Known Issues

* Remote node is not working
* Only works on Linux


## 0.1.1 (2020-10-22)

### Bug fixes

* Remove % from load.cpu so it can be plotted

### Known Issues

* Remote node is not working
* Only works on Linux


## 0.1.0 (2020-10-22)

### Features

* Configurable number of listed processes
* Configurable interval
* Start, Stop, Pause, and change configuration options
* Print results to
  * IO leader
  * text file
  * exs file
* exs file logging allow loading and post processing results
* ASCII charting of results

### Known Issues

* Remote node is not working
* Only works on Linux
