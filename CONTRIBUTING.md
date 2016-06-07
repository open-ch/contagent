# Contributing to Contagent

Thank you for thinking about contributing!

If you'd like to seemlessly meld your work into ours it might be helpful to use the following guidelines as an orientation.

## Background Information
#### File Structure
The repository is organized in a way that is similar to nginx' file structure and consists of 3 main parts:

* **conf** - the configuration files (+ certificates) for the nginx server
  * **certs** - configuration files for certificate generation using cfssl (will be replaced by actual certs during installation)
  * **domains** - nginx config files for the different subdomains (included in top.conf by wildcard)
  * **includes** - common configuration snippets used in several nginx config files
* **html** - the content (html files as well as others)
  * **default** - contains index.html printing server name using SSI
  * **index** - web GUI for quick tests
  * **malware** - selection of malware to test antimalware
  * **mediatype** - files with strange media types to test media type filters
* **perl** - perl modules processing specific requests, are imported into nginx

#### Install Script
The install script takes care of

* replacing the dummy variables of the form `[% DUMMY_VARIABLE %]`
* generating certificates and archives
* moving the files to their dedicated paths inside the nginx file structure

The original repository does not get touched during that process.

## How to contribute
Most of you probably won't need the following, but nevertheless it should be acknoledged by the rest that we ask you to...

* Comment your code
* Document the functionality
* Add a punchy message to your commit
* Please stick to the current structure, whenever possible. If you think a change might be reasonable, please adjust the existing files to match your proposal before making a pull request, so that the structure is uniform at any point in time.