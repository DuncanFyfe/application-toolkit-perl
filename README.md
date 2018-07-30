application-toolkit-perl
========================

A collection of Perl modules I reach for when writting Perl applications and scripts.
The modules are:

* AppConfig    - Unifies the command line with a configuration file.
* Csv::Reader  - Methods for standardized CSV reading and CSV parsing failure correction.
* Csv::Writer  - Methods for standardized CSV writing.
* Daemonize    - All the nasty bits of daemonization wrapped up in an easy to use package.
* Date         - Methods for handling dates.
* Exception    - Wrap error information in an object and then use standard per (eg. die) to "throw" it.
* Exec         - Wrap various ways of calling other code and convert problems into Exceptions.
* Msg          - Logging interface built ontop of Log::Dispatch
* File::Compression - Simple interface for bulk file compression and decompression.
* File::Lock   - Lock files which can be used to protect contended resources in shared and clustered environments.
* File::Pid    - Specialised File::Lock used to indicate an instance of a process (eg. Daemons) is already running.
* File::Serial - File backed persistent sequence of numbers which can be used in a shared and clustered environments.
* Timestamp    - Timestamps used to record time during processing.


