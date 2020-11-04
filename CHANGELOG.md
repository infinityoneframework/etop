# Etop Changelog

## 0.7.0 (2020-11-04)

### Features

* Support for Montitor watchers

## 0.6.1 (2020-11-02)

### Bug fixes

* Fix {Module, Function} callback regression


## 0.6.0 (2020-10-31)

### Features

* Allow monitors to return an updated state

## 0.5.4 (2020-10-29)

### Bug fixes

* Fix msgq sort option

## 0.5.3 (2020-10-29)

### Features

* Add Humanize option (default true)

### Bug fixes

* Fix sort option
* Fix sorting when printing from exs log
* Fix tests that break when run on systems with different core counts.

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
