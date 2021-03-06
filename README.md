![logo][1]
# Contagent

## Introduction
**Contagent** (Connection test agent) is an addon to nginx that creates HTTP(S) servers offering a variety of different behaviours and defects – just like you may find them on the internet. But unlike in the 'real' world the behaviour of your Contagent server is predictable and it will respond to a specific request in a specific way. This reproducibility makes **Contagent** a handy tool for testing the behaviours of clients and/or intermediate devices like proxies.  
An Example for defects Contagent offers are certificates considered to be insecure (which was inspired by [BadSSL.com](https://badssl.com)). But it also provides some quick http tests inspired by [httpbin.org](https://httpbin.org) and some test malware provided by [wicar.org](http://wicar.org/), too. **Contagent** does not claim to have the same functional variety as those projects mentioned above, but it merely aims to provide a more general toolkit to tackle a broader spectrum.  
Installing **Contagent** on your host, provides the basics for the server end of an end-to-end test environment for your network infrastructure.

## Test Cases
* TLS Connection / Server Certificates
* Certificate black/whitelists
* Malware
* Mediatypes
* Archive Handling
* HTTP Processing
* URL Filter

## Requirements
* linux (does not work on Mac OS or Windows)
  * the `sed -i` option should not expect an argument
* perl - including the modules:
  * nginx
  * JSON::XS
* [nginx](http://nginx.org/) - server installation
* [cfssl](https://github.com/cloudflare/cfssl/) - certificate generation tool
* [jq](https://stedolan.github.io/jq/) - command-line JSON processor

#### Github Dependencies
* [github / malware.wicar.org / data](https://github.com/wicar/malware.wicar.org/tree/master/data)

## Installation
This installation guide assumes that you already have installed all the programs listed under "Requirements" and you also know the path to your nginx base directory / prefix.

1. Clone this repository to your local machine

        $ cd ~/local/directory
        $ git clone https://github.com/open-ch/contagent.git


2. Run the install script that is inside the freshly cloned repository
        
        $ ./install.sh
        
    The script will prompt for the information needed to install the server configuration to the right place (the base directory / prefix of your nginx installation)  
  This information can also be passed to the script using command line options. For help on all the options you can set run `$ ./install.sh -h`


3. After the installation process has been completed you will have at least three directories inside your nginx base directory
        
        $ ls nginx/prefix/
        conf/     html/     perl/     [...]
        
    Inside those directories there will be a directory with the name you specified to be your project name during the installation process
  
        $ ls nginx/prefix/conf/
        project_name/     [...]
        
    In the `conf/` subdirectory you should also have the main config file for nginx: `nginx.conf` (if you don't, create it). As indicated at the end of the install sript you now have to include  `project_name/top.conf` into that file's `http { ... }` section. The minimal content should look something like this:
        
        # conf/nginx.conf
        
        events {
        }
        
        http {
            include mime.types;
            include project_name/top.conf;
        }


4. (Re)start nginx

That's enough to have a basic configuration. If you want to add more configuration, see section [Custom Server Configuration](#custom-server-configuration).

## Configure Intermediate Hosts
If you you want to test intermediate devices there are some features Contagent has to offer for that, too.  
The subdomains mentioned below may inspire you to configure your intermediate host according to what their names suggest.  
This means: On that device ...

* Add the subdomains 'urlfilterwhitelist' and 'urlfilterblacklist' to the url filter whitelist or blacklist, respectively.
* Add entries for the subdomains 'cert-whitelist-domainname', 'cert-whitelist-fingerprint', 'cert-blacklist-domainname', 'cert-blacklist-fingerprint' to the matching white-/blacklist
* Add to the mediatype filter configuration, that some of the files in `html/project_name/mediatype/` should get blocked and others shouldn't

## Usage
| You want to test | Then, via the connection to test, try to access |
|:---|:---|
| **SSL/TLS Vulnerabilities** | the different subdomains specified in `conf/project_name/domains/*.conf` |
| **Certificate black/whitelists** | the subdomains 'cert-whitelist-domainname', 'cert-whitelist-fingerprint', 'cert-blacklist-domainname', 'cert-blacklist-fingerprint' (after you have added entries to the appropriate lists, of course) |
| **Malware Detection** | malware in the `html/project_name/malware/` directory |
| **Mediatype Filtering** | files in the `html/project_name/mediatype/` directory |
| **Archive Handling** | archives in the `html/project_name/archive/` directory |
| **HTTP Processing** | locations specified in `conf/project_name/domains/http.conf` |
| **URL Filter** | the subdomains 'urlfilterwhitelist' and 'urlfilterblacklist' (after you have added entries to the appropriate lists, of course) |


## Custom Server Configuration
This guide shows how to change an existing **Contagent** installation, not the repository itself.

#### Customizing Servers

At this point it is recommended you know how to configure an ngix server as it basically is nothing more than that.  
The server configuration takes place in the `nginx/prefex/conf/domains/*.conf` files. They are included by `top.conf` (which is included by `nginx.conf`)  
In order to add a new server just create a new file analogously to the files already existing.
Of course you may also modify or delete existing servers.

#### Customizing Content

The content is located in the `nginx/prefex/html/project_name/` directory.
As a default every server responds by sending the `default/index.html` page which just displays the server name using SSI.  
The other files can be accessed via the `content` subdomain and adding the path from `html/project_name` to the url.  
Of course content can be added, modified, deleted as you wish.



[1]: contagent_logo.png "Contagent"