#!/bin/bash

# Pastikan skrip dijalankan sebagai root
if [ "$(id -u)" -ne 0 ]; then
    echo "Skrip ini harus dijalankan sebagai root" >&2
    exit 1
fi

# Mengatur versi dan direktori instalasi
OPENSSL_VERSION="1.1.1l"
OPENSSL_DIR="/usr/local/ssl"
MAKE_CA_VERSION="1.1"
MAKE_CA_URL="https://github.com/dotzero/make-ca/archive/refs/tags/v$MAKE_CA_VERSION.tar.gz"
GIT_VERSION="2.34.1"
GIT_URL="https://github.com/git/git/archive/refs/tags/v$GIT_VERSION.tar.gz"

# Langkah 1: Menginstal OpenSSL 1.1.1l
echo "[+] Mengunduh dan menginstal OpenSSL 1.1.1l..."
wget --no-check-certificate https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz -O /tmp/openssl-$OPENSSL_VERSION.tar.gz
cd /tmp
tar -xvzf openssl-$OPENSSL_VERSION.tar.gz
cd openssl-$OPENSSL_VERSION
./config --prefix=$OPENSSL_DIR --openssldir=/etc/ssl
make
sudo make install

# Menambahkan OpenSSL ke dalam PATH
echo "[+] Menambahkan OpenSSL ke dalam PATH..."
echo "export PATH=$OPENSSL_DIR/bin:\$PATH" >> ~/.bashrc
echo "export LD_LIBRARY_PATH=$OPENSSL_DIR/lib:\$LD_LIBRARY_PATH" >> ~/.bashrc
source ~/.bashrc

# Verifikasi Instalasi OpenSSL
openssl version

# Langkah 2: Menginstal Git
echo "[+] Mengunduh dan menginstal Git $GIT_VERSION..."
cd /tmp
wget --no-check-certificate $GIT_URL -O /tmp/git-$GIT_VERSION.tar.gz
tar -xvzf /tmp/git-$GIT_VERSION.tar.gz
cd git-$GIT_VERSION

# Mengonfigurasi Git untuk menggunakan OpenSSL 1.1.x
make configure
./configure --prefix=/usr --with-openssl=$OPENSSL_DIR
make
sudo make install

# Verifikasi Instalasi Git
git --version

# Langkah 3: Menginstal make-ca
echo "[+] Mengunduh dan menginstal make-ca..."
mkdir -p /usr/local/src
cd /usr/local/src
wget --no-check-certificate $MAKE_CA_URL -O make-ca-$MAKE_CA_VERSION.tar.gz
tar -xvzf make-ca-$MAKE_CA_VERSION.tar.gz
cd make-ca-$MAKE_CA_VERSION

# Membuat dan menginstal make-ca
make
sudo make install

# Verifikasi Instalasi make-ca
if command -v make-ca > /dev/null; then
    echo "[+] make-ca berhasil diinstal."
else
    echo "[-] make-ca gagal diinstal." >&2
    exit 1
fi

# Langkah 4: Mengonfigurasi CA
echo "[+] Mengonfigurasi CA..."
CA_DIR="/etc/ssl/myCA"
mkdir -p $CA_DIR/newcerts
touch $CA_DIR/myCAindex
touch $CA_DIR/myCAserial

cat > $CA_DIR/myCAconfig.cnf << EOF
[ ca ]
default_ca = CA_default

[ CA_default ]
dir = $CA_DIR
certificate = $CA_DIR/myCA.pem
private_key = $CA_DIR/myCA.key
new_certs_dir = $CA_DIR/newcerts
database = $CA_DIR/myCAindex
serial = $CA_DIR/myCAserial
RANDFILE = $CA_DIR/myCA.rnd
default_md = sha256
policy = policy_match

[ policy_match ]
commonName = supplied

[ req ]
default_bits = 2048
default_keyfile = $CA_DIR/myCA.key
distinguished_name = req_distinguished_name
x509_extensions = v3_ca

[ req_distinguished_name ]
commonName = Common Name (e.g. server FQDN or YOUR name)

[ v3_ca ]
basicConstraints = CA:true
EOF

# Membuat CA (Self-Signed Certificate)
echo "[+] Membuat sertifikat CA..."
openssl req -new -x509 -days 3650 -keyout $CA_DIR/myCA.key -out $CA_DIR/myCA.pem -config $CA_DIR/myCAconfig.cnf

# Menambahkan sertifikat CA ke sistem
echo "[+] Menambahkan sertifikat CA ke sistem..."
cp $CA_DIR/myCA.pem /usr/local/share/ca-certificates/
update-ca-certificates

# Verifikasi Sertifikat CA
openssl x509 -in /usr/local/share/ca-certificates/myCA.pem -text -noout

echo "[+] OpenSSL 1.1.1l, Git, dan make-ca berhasil diinstal dan dikonfigurasi."
