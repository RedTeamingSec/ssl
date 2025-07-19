#!/bin/bash

# Pastikan skrip dijalankan sebagai root
if [ "$(id -u)" -ne 0 ]; then
    echo "Skrip ini harus dijalankan sebagai root" >&2
    exit 1
fi

# Mengatur direktori untuk CA
CA_DIR="/etc/ssl/myCA"
mkdir -p $CA_DIR/newcerts
touch $CA_DIR/myCAindex
touch $CA_DIR/myCAserial

# Membuat file konfigurasi untuk CA
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

# Membuat kunci pribadi untuk CA
echo "[+] Membuat kunci pribadi untuk CA..."
openssl genpkey -algorithm RSA -out $CA_DIR/myCA.key -aes256
if [ $? -ne 0 ]; then
    echo "Gagal membuat kunci pribadi untuk CA." >&2
    exit 1
fi

# Membuat sertifikat self-signed untuk CA
echo "[+] Membuat sertifikat self-signed untuk CA..."
openssl req -new -x509 -days 3650 -key $CA_DIR/myCA.key -out $CA_DIR/myCA.pem -config $CA_DIR/myCAconfig.cnf
if [ $? -ne 0 ]; then
    echo "Gagal membuat sertifikat self-signed untuk CA." >&2
    exit 1
fi

# Menambahkan sertifikat CA ke sistem
echo "[+] Menambahkan sertifikat CA ke sistem..."
cp $CA_DIR/myCA.pem /usr/local/share/ca-certificates/
update-ca-certificates
if [ $? -ne 0 ]; then
    echo "Gagal menambahkan sertifikat CA ke sistem." >&2
    exit 1
fi

# Verifikasi sertifikat CA
echo "[+] Verifikasi sertifikat CA..."
openssl x509 -in /usr/local/share/ca-certificates/myCA.pem -text -noout
if [ $? -ne 0 ]; then
    echo "Gagal memverifikasi sertifikat CA." >&2
    exit 1
fi

echo "[+] CA baru berhasil dibuat dan ditambahkan ke sistem."
