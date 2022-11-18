#!/bin/bash

set -o nounset \
    -o errexit \
    -o verbose \
    -o xtrace

# VARS
SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
# shellcheck source=/dev/null
source "${SCRIPTPATH}/.env"
OUT_PATH="${SCRIPTPATH}/secrets"


SSL_CA_CN="ca1.orgname.local"
SSL_CA_DAYS=365
SSL_OU="TEST"
SSL_O="ORGNAME"
SSL_L="LOCAL"
SSL_S="PC"
SSL_C="LO"

# FUNC
concatenate_paths() {
   base_path=${1}
   sub_path=${2}
   full_path="${base_path:+$base_path/}$sub_path"
   echo "${full_path}"
}

generate_pem_certs() {
  local _cn_name=${1}
  openssl genrsa -des3 -passout "pass:${JKS_PASS}" -out "$(concatenate_paths ${OUT_PATH} ${_cn_name}.key)" 1024
  openssl req -passin "pass:${JKS_PASS}" -passout "pass:${JKS_PASS}" \
    -key "$(concatenate_paths ${OUT_PATH} ${_cn_name}.key)" -new \
    -out "$(concatenate_paths ${OUT_PATH} ${_cn_name}.req)" \
    -subj "/CN=${_cn_name}/OU=${SSL_OU}/O=${SSL_O}/L=${SSL_L}/S=${SSL_S}/C=${SSL_C}"
  openssl x509 -req \
    -CA "$(concatenate_paths ${OUT_PATH} snakeoil-ca-1.crt)" \
    -CAkey "$(concatenate_paths ${OUT_PATH} snakeoil-ca-1.key)" \
    -in "$(concatenate_paths ${OUT_PATH} ${_cn_name}.req)" \
    -out "$(concatenate_paths ${OUT_PATH} ${_cn_name}.pem)" \
    -days 9999 -CAcreateserial -passin "pass:${JKS_PASS}"

  rm -f "$(concatenate_paths ${OUT_PATH} ${_cn_name}.req)" 
}

generate_jks_certs() {
  local _file_name=${1}
  local _cn_name=${2}
  # Create keystores
        # TODO: -ext SAN=dns:abc.com,ip:1.1.1.1 add SAN to brokers to be able connect to brokers outside of docker
        # https://docs.oracle.com/javase/7/docs/technotes/tools/solaris/keytool.html
	keytool -genkey -noprompt \
				 -alias ${_cn_name} \
				 -dname "CN=${_cn_name}, OU=${SSL_OU}, O=${SSL_O}, L=${SSL_L}, S=${SSL_S}, C=${SSL_C}" \
                                 -ext SAN=dns:localhost,ip:127.0.0.1 \
                                 -ext SAN=dns:$(hostname) \
				 -keystore "$(concatenate_paths ${OUT_PATH} ${_file_name}.keystore.jks)" \
				 -keyalg RSA \
				 -storepass "${JKS_PASS}" \
				 -keypass "${JKS_PASS}"

	# Create CSR, sign the key and import back into keystore
	keytool -noprompt -keystore "$(concatenate_paths ${OUT_PATH} ${_file_name}.keystore.jks)" \
    -alias "${_cn_name}" -certreq \
    -file "$(concatenate_paths ${OUT_PATH} ${_file_name}.csr)" \
    -storepass "${JKS_PASS}" -keypass "${JKS_PASS}"

	openssl x509 -req \
    -CA "$(concatenate_paths ${OUT_PATH} snakeoil-ca-1.crt)" \
    -CAkey "$(concatenate_paths ${OUT_PATH} snakeoil-ca-1.key)" \
    -in "$(concatenate_paths ${OUT_PATH} ${_file_name}.csr)" \
    -out "$(concatenate_paths ${OUT_PATH} ${_file_name}-signed.csr)" -days 9999 \
    -CAcreateserial -passin pass:"${JKS_PASS}"

	keytool -noprompt -keystore "$(concatenate_paths ${OUT_PATH} ${_file_name}.keystore.jks)" \
    -alias CARoot -import -file "$(concatenate_paths ${OUT_PATH} snakeoil-ca-1.crt)" \
    -storepass "${JKS_PASS}" -keypass "${JKS_PASS}"

	keytool -noprompt -keystore "$(concatenate_paths ${OUT_PATH} ${_file_name}.keystore.jks)" \
  -alias "${_cn_name}" -import \
  -file "$(concatenate_paths ${OUT_PATH} ${_file_name}-signed.csr)" \
  -storepass "${JKS_PASS}" -keypass "${JKS_PASS}"

	# Create truststore and import the CA cert.
	keytool -noprompt -keystore "$(concatenate_paths ${OUT_PATH} ${_file_name}.truststore.jks)" \
    -alias CARoot -import -file "$(concatenate_paths ${OUT_PATH} snakeoil-ca-1.crt)" \
    -storepass "${JKS_PASS}" -keypass "${JKS_PASS}"

  rm -f "$(concatenate_paths ${OUT_PATH} ${_file_name}.csr)" \
        "$(concatenate_paths ${OUT_PATH} ${_file_name}-signed.csr)"
}


# Generate CA key
openssl req -new -x509 -keyout "$(concatenate_paths "${OUT_PATH}" snakeoil-ca-1.key)" -out "$(concatenate_paths "${OUT_PATH}" snakeoil-ca-1.crt)" -days "${SSL_CA_DAYS}" -subj "/CN=${SSL_CA_CN}/OU=${SSL_OU}/O=${SSL_O}/L=${SSL_L}/S=${SSL_S}/C=${SSL_C}" -passin pass:"${JKS_PASS}" -passout pass:"${JKS_PASS}"
# openssl req -new -x509 -keyout snakeoil-ca-2.key -out snakeoil-ca-2.crt -days 365 -subj '/CN=ca2.test.confluent.io/OU=${SSL_OU}/O=${SSL_O}/L=${SSL_L}/S=${SSL_S}/C=${SSL_C}" -passin pass:"${JKS_PASS}" -passout pass:"${JKS_PASS}"

# Kafkacat
generate_pem_certs "kafkacat"


for i in broker1 broker2 ksm sr rest cmak akhq
do
	echo $i
	SSL_CN="$i"
	generate_jks_certs "$i" "${SSL_CN}"
done
echo "${JKS_PASS}" > "$(concatenate_paths "${OUT_PATH}" creds)"
