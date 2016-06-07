#!/bin/bash
set -eu -o pipefail

# This script copies all data needed to configure the server to a temporary directory, replaces all the dummy variables, generates certificates and archives and eventually moves the result to the nginx configuration path (prefix)

CALLPATH=`pwd`
SCRIPTPATH=$(cd $(dirname ${0}) && pwd)

PATH_TO_SERVER_DIR="$SCRIPTPATH"
TEMP_DIR=$(mktemp -d)

error_exit()
{
	echo "$1" 1>&2
	exit 1
}

# Check Provided Options
OPTIONS=`getopt --name $0 --options "h" --longoptions "help,server:,project:,nginx-prefix:,root-ca:,root-ca-key:,country:,state:,location:,organization:,org-unit:,crl-out:" -- "$@"`
[ $? = 0 ] || exit 1

HELP=false
eval set -- "$OPTIONS"
while true; do
    case $1 in
        '-h'|'--help')
            HELP=true
            break;
        ;;

        '--server')
            SERVER_NAME="$2"
            shift; shift; continue
        ;;

        '--project')
            PROJECT_NAME="$2"
            shift; shift; continue
        ;;

        '--nginx-prefix')
            NGINX_PREFIX="$2"
            shift; shift; continue
        ;;

        '--root-ca')
            ROOT_CA="$2"
            shift; shift; continue
        ;;

        '--root-ca-key')
            ROOT_CA_KEY="$2"
            shift; shift; continue
        ;;

        '--country')
            CERT_COUNTRY="$2"
            shift; shift; continue
        ;;

        '--state')
            CERT_STATE="$2"
            shift; shift; continue
        ;;

        '--location')
            CERT_LOCATION="$2"
            shift; shift; continue
        ;;

        '--organization')
            CERT_ORGANIZATION="$2"
            shift; shift; continue
        ;;

        '--org-unit')
            CERT_ORG_UNIT="$2"
            shift; shift; continue
        ;;

        '--crl-out')
            CRL_OUT_FILE="$2"
            shift; shift; continue
        ;;
        
        '--')
            break
        ;;

        *)
            HELP=true
            break
        ;;

    esac
done

# Check if requirements for running this script are met
check_requirements() {
    sed --help > /dev/null
    cfssl print-defaults list > /dev/null
    echo {} | jq . > /dev/null
}

# Prompt for options not set as arguments
prompt_for_missing_arguments() {
	if [[ -z ${SERVER_NAME+"x"} ]];       then read -p "Please specify server name (domain name): "                              SERVER_NAME ; fi
	if [[ -z ${PROJECT_NAME+"x"} ]];      then read -p "Please specify project name (will determine lables): "                   PROJECT_NAME ; fi
	if [[ -z ${NGINX_PREFIX+"x"} ]];      then read -p "Please specify nginx prefix (main path to nginx config and data): "      NGINX_PREFIX ; fi
}

# Copy everything to temp directory
copy_to_tmp() {
	mkdir -p $TEMP_DIR/"$PROJECT_NAME"
	rm -rf $TEMP_DIR/"$PROJECT_NAME"/*
	cp -r "$PATH_TO_SERVER_DIR"/* $TEMP_DIR/"$PROJECT_NAME"/
}

handle_root_ca() {
    # Copy root ca cert and key to dedicated path in TEMP_DIR if they were specified and they exist
    if [[ -f "${ROOT_CA-''}" && -f "${ROOT_CA_KEY-''}" ]]
    then
        echo "**** Using specified root certificate ($ROOT_CA) and private key ($ROOT_CA_KEY) ..."
        cp "$ROOT_CA" $TEMP_DIR/"$PROJECT_NAME"/conf/certs/root.pem
        cp "$ROOT_CA_KEY" $TEMP_DIR/"$PROJECT_NAME"/conf/certs/root-key.pem
        local cert_json
        
        # Exit if supplied root ca cannot be read by cfssl certinfo, if, e.g., it contains a certificate chain
        cert_json=$(cfssl certinfo -cert "$ROOT_CA") || error_exit '**** !! Problem while parsing root ca (cfssl only takes single certificates, no chains) !!'
        
        # If not set as argument use names from root ca
    	if [[ -z ${CERT_COUNTRY+"x"} ]];      then CERT_COUNTRY=$(echo $cert_json      | jq --raw-output .subject.country) ; fi
    	if [[ -z ${CERT_STATE+"x"} ]];        then CERT_STATE=$(echo $cert_json        | jq --raw-output .subject.province) ; fi
    	if [[ -z ${CERT_LOCATION+"x"} ]];     then CERT_LOCATION=$(echo $cert_json     | jq --raw-output .subject.locality) ; fi
    	if [[ -z ${CERT_ORGANIZATION+"x"} ]]; then CERT_ORGANIZATION=$(echo $cert_json | jq --raw-output .subject.organization) ; fi
    	if [[ -z ${CERT_ORG_UNIT+"x"} ]];     then CERT_ORG_UNIT=$(echo $cert_json     | jq --raw-output .subject.organizational_unit) ; fi
    else
        echo "**** Generating new root certificate and private key ..."
    	if [[ -z ${CERT_COUNTRY+"x"} ]];      then read -p "Please specify country for certificate generation: "                     CERT_COUNTRY ; fi
    	if [[ -z ${CERT_STATE+"x"} ]];        then read -p "Please specify state for certificate generation: "                       CERT_STATE ; fi
    	if [[ -z ${CERT_LOCATION+"x"} ]];     then read -p "Please specify location for certificate generation: "                    CERT_LOCATION ; fi
    	if [[ -z ${CERT_ORGANIZATION+"x"} ]]; then read -p "Please specify organization for certificate generation: "                CERT_ORGANIZATION ; fi
    	if [[ -z ${CERT_ORG_UNIT+"x"} ]];     then read -p "Please specify name of organizational unit for certificate generation: " CERT_ORG_UNIT ; fi
    fi
    
    # Set unset variables to the empty string
    CERT_COUNTRY="${CERT_COUNTRY-''}"
    CERT_STATE="${CERT_STATE-''}"
    CERT_LOCATION="${CERT_LOCATION-''}"
    CERT_ORGANIZATION="${CERT_ORGANIZATION-''}"
    CERT_ORG_UNIT="${CERT_ORG_UNIT-''}"
    
}

# Replace [% VARIABLES %] with corresponding values
replace_dummyvariables() {
    find "$TEMP_DIR/$PROJECT_NAME/conf" -type f -exec sed -i -e "s|\[% SERVER_NAME %\]|$SERVER_NAME|g" \
                                                        -e "s|\[% PROJECT_NAME %\]|$PROJECT_NAME|g" \
                                                        -e "s|\[% CERT_COUNTRY %\]|$CERT_COUNTRY|g" \
                                                        -e "s|\[% CERT_STATE %\]|$CERT_STATE|g" \
                                                        -e "s|\[% CERT_LOCATION %\]|$CERT_LOCATION|g" \
                                                        -e "s|\[% CERT_ORGANIZATION %\]|$CERT_ORGANIZATION|g" \
                                                        -e "s|\[% CERT_ORG_UNIT %\]|$CERT_ORG_UNIT|g" {} \;
}

# Generate certificates using cfssl
generate_certificates() {
    
	SAVEPWD=`pwd`
	cd $TEMP_DIR/"$PROJECT_NAME"/conf/certs/

	# Generate root cert if not existing or if explicitly specified with --regenerate_root
	if [[ ! -f root.pem || ! -f root-key.pem ]]
	then
		cfssl gencert -initca csr_root.json | cfssljson -bare root
		cfssl sign -ca root.pem -ca-key root-key.pem -config conf_root.json root.csr | cfssljson -bare root
	fi

	# Generate intermediate cert
	cfssl gencert -ca root.pem -ca-key root-key.pem -config conf_intermediate.json csr_intermediate.json | cfssljson -bare intermediate

	# Generate all the other certs
	cfssl gencert -ca intermediate.pem -ca-key intermediate-key.pem -config conf_exp2years.json csr_wildcard.json   | cfssljson -bare wildcard-normal
	cfssl gencert -ca intermediate.pem -ca-key intermediate-key.pem -config conf_exp2years.json csr_wildcard.json   | cfssljson -bare blacklist-fingerprint
	cfssl gencert -ca intermediate.pem -ca-key intermediate-key.pem -config conf_exp2years.json csr_cert-blacklist-domainname.json   | cfssljson -bare blacklist-domainname
	cfssl gencert -ca intermediate.pem -ca-key intermediate-key.pem -config conf_expired.json   csr_wildcard.json   | cfssljson -bare wildcard-expired
	cfssl gencert -ca intermediate.pem -ca-key intermediate-key.pem -config conf_exp2years.json csr_wrong-host.json | cfssljson -bare wrong-host

	cfssl gencert -ca intermediate.pem -ca-key intermediate-key.pem -config conf_exp2years.json csr_1000-sans.json  | cfssljson -bare 1000-sans
	cfssl gencert -ca intermediate.pem -ca-key intermediate-key.pem -config conf_exp2years.json csr_10000-sans.json | cfssljson -bare 10000-sans

	cfssl gencert -ca intermediate.pem -ca-key intermediate-key.pem -config conf_exp2years.json csr_wildcard-rsa4096.json | cfssljson -bare wildcard-rsa4096
    
    cfssl gencert -ca intermediate.pem -ca-key intermediate-key.pem -config conf_exp2years.json csr_wildcard.json | cfssljson -bare wildcard-revoked
	
	# make complete certificate chains
	for file in $(find * -name "*.pem" -not -name "*-key.pem" -not -name "root.pem" -not -name "intermediate.pem")
	do
        cp "$file" "${file%.pem}-nochain.pem"
		cat intermediate.pem root.pem >> "$file"
	done
	
    # Self-signed
	cfssl gencert -initca csr_wildcard.json | cfssljson -bare wildcard-self-signed
	cfssl sign -ca wildcard-self-signed.pem -ca-key wildcard-self-signed-key.pem -config conf_exp2years.json wildcard-self-signed.csr | cfssljson -bare wildcard-self-signed
    
    # Incomplete chain
	cfssl gencert -ca intermediate.pem -ca-key intermediate-key.pem -config conf_exp2years.json csr_wildcard.json | cfssljson -bare wildcard-incomplete-chain
	cfssl gencert -ca intermediate.pem -ca-key intermediate-key.pem -config conf_exp2years.json csr_wildcard.json | cfssljson -bare whitelist-fingerprint
	cfssl gencert -ca intermediate.pem -ca-key intermediate-key.pem -config conf_exp2years.json csr_wildcard.json | cfssljson -bare whitelist-domainname
    
    # cfssl chooses signing algorithm according to private-key length of signing certificate -> intermediate with 4096bit private key signs with sha512
	cfssl gencert -ca root.pem -ca-key root-key.pem -config conf_intermediate.json csr_intermediate4096.json | cfssljson -bare intermediate4096
    cfssl gencert -ca intermediate4096.pem -ca-key intermediate4096-key.pem -config conf_exp2years.json csr_wildcard.json | cfssljson -bare sha512-wildcard
    cat intermediate4096.pem root.pem >> sha512-wildcard.pem
    
    # Generate crl for revoked certificate and copy to specified path (if specified)
    if [[ -n "${CRL_OUT_FILE-}" ]];
    then
        cfssl certinfo -cert wildcard-revoked-nochain.pem | jq --raw-output .serial_number | cfssl gencrl - intermediate.pem intermediate-key.pem \
            | base64 -d | openssl crl -outform PEM -inform DER -text -out "$CRL_OUT_FILE"
    fi

	# Delete all the json formatted cfssl config files
    rm *.json
	cd "$SAVEPWD"
}

# Generate archives
generate_archives() {
	# Generate zip from random numbers (arguments: zip file to be created, range of numbers, count of numbers, repetition of the resulting string)
	get_random_zip() {
        local zipfile=$1
		local range=$2
		local numberscount=$3
		local repetitions=$4
		local randomtext=""

		local number=0
		while [ $number -lt $numberscount ]
		do
			randomtext="$randomtext$(( RANDOM % $range ))"
			((++number))
		done
		
		echo -n $randomtext > tmp
		
		local rep=1
		# double file content
		while [ $((rep * 2)) -le $repetitions ]
		do
			cat tmp >> tmp1
			cat tmp >> tmp1
			mv tmp1 tmp
			rep=$((rep * 2))
		done
		# write rest one by one
		while [ $rep -lt $repetitions ]
		do
			echo -n $randomtext >> tmp
			((++rep))
		done

		rm -f $zipfile
		zip -q $zipfile tmp
	}
	
	# Generate recursive zip archives (arguments: zip file, how many recursions)
	recursive_zip() {
		local zipfile=$1
        local zipname="${zipfile%.*}"
		local recursions=$2
		local recur=0
		cp $zipfile $zipname-0.zip

		for (( R=1; R<=$recursions; R++ ))
		do
			zip -q $zipname-$R.zip $zipname-$(expr $R - 1).zip
			# rm tmp_$(expr $R - 1).zip
		done
	}
	
	SAVEPWD=`pwd`
	mkdir -p $TEMP_DIR/"$PROJECT_NAME"/html/archive/
	cd $TEMP_DIR/"$PROJECT_NAME"/html/archive/
	
	# Make archives with specific compression ratios
	get_random_zip ratio-10.zip 1000 10000 6
	
	get_random_zip ratio-120.zip 1000 7000 512
	
	get_random_zip ratio-166.zip 1000 1000 4096
	
	get_random_zip ratio-200.zip 10 1000 32768
	
	get_random_zip ratio-300.zip 10 100 131072
	
	# Make archives with specific amount of compressing recursions
	get_random_zip recursion-tmp.zip 10 26 1000
	recursive_zip recursion-tmp.zip 300
	mv recursion-tmp-100.zip recursion-100.zip
	mv recursion-tmp-150.zip recursion-150.zip
	mv recursion-tmp-200.zip recursion-200.zip
	mv recursion-tmp-250.zip recursion-250.zip
	mv recursion-tmp-300.zip recursion-300.zip
	rm recursion-tmp-*.zip
	
	# Generate archives containing file with specific size
	#get_random_zip 1000 5900 65536
	#mv tmp.zip size_1-1GB.zip
	
	#get_random_zip 1000 5000 32768
	#mv tmp.zip size_500MB.zip
	
	cd "$SAVEPWD" 
}

# (TODO generate files for mediatype filter test)


# Copy everything to its target path (promt for it)
copy_to_nginx() {
	for nginxfolder in conf html perl
	do
		mkdir -p "$NGINX_PREFIX/$nginxfolder/$PROJECT_NAME"
		rm -rf "$NGINX_PREFIX/$nginxfolder/$PROJECT_NAME"/*
		cp -r "$TEMP_DIR/$PROJECT_NAME/$nginxfolder"/* "$NGINX_PREFIX/$nginxfolder/$PROJECT_NAME/"
	done
}

# Either display usage or execute
if [[ $HELP == true ]]
then
    echo "$0"
    echo "    --help                   Display this info"
    echo
    echo "  Options:"
    echo "    --server <SERVER_NAME>      Name of server like server.name.com"
	echo "    --project <PROJECT_NAME>    What you want to call that server, representative"
	echo "    --nginx-prefix <PREFIX>     Main path to nginx config and data"
	echo "    --root-ca <path/to/CA>      Root CA to use as Issuer for intermediate certificate"
    echo "                                  (generate new one if not specified)"
	echo "    --root-ca-key <path/to/KEY> Key corresponding to Root CA specified in --root-ca <CA>"
    echo "                                  (generate new root CA if not specified)"
	echo "  Certificate Options:"
	echo "    --country <CO>              Name of country in two letters"
	echo "    --state <ST>                Name of state"
	echo "    --location <LOCATION>       Name of city"
	echo "    --organization <O>          Name of organization"
	echo "    --org-unit <OU>             Name of rganzational unit"
    exit 1
fi

# Execute methods defined above
echo -n "**** Checking if requirements for installation are met ..."
check_requirements
echo " OK!"

prompt_for_missing_arguments

echo "**** Copying files to $TEMP_DIR/$PROJECT_NAME ..."
copy_to_tmp
handle_root_ca

echo "**** Replacing dummy variables ..."
replace_dummyvariables

echo "**** Generating certificates ..."
generate_certificates
echo "**** Generating archives ..."
generate_archives

echo "**** Copying prepared data to nginx main directory ..."
copy_to_nginx
rm -r $TEMP_DIR

echo "**** DONE."
echo "# !! Please include $NGINX_PREFIX/conf/$PROJECT_NAME/top.conf into http{} section of $NGINX_PREFIX/conf/nginx.conf file, i.e."
echo "# http {"
echo "#     ..."
echo "#     include $PROJECT_NAME/top.conf;"
echo "# }"


exit 0