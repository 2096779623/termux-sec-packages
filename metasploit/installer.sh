#!/data/data/com.termux/files/usr/bin/bash

set -e
export PREFIX=/data/data/com.termux/files/usr

# Lock terminal to prevent sending text input and special key
# combinations that may break installation process.
stty -echo -icanon time 0 min 0 intr undef quit undef susp undef

# Use trap to unlock terminal at exit.
trap 'while read -r; do true; done; stty sane;' EXIT

if [ "$(id -u)" = "0" ]; then
	echo "[!] Sorry but I won't let you to install this package as root."
	exit 1
fi

FOLD_COLUMNS=45
if [[ $COLUMNS =~ ([[:digit:]]) ]] && ((COLUMNS < FOLD_COLUMNS)); then
	FOLD_COLUMNS=$COLUMNS
fi

echo
echo "======= TERMUX METASPLOIT DISCLAIMER ======="
{
	echo
	echo "Metasploit Framework and its dependencies are being sideloaded.  That solution makes package potentially unstable.  We do not guarantee compatibility of installed Ruby modules with our Ruby interpreter version and general compatibility with Android OS."
	echo
	echo "It is highly recommended to have a stable Internet connection and clean Termux environment with up-to-date packages before installing Metasploit."
	echo
	echo "Package is intended to be used by experienced users.  Do not ask Termux developers about how to use Metasploit, we won't do so and generally are not helping anyone with topics related to hacking."
	echo
	echo "Installation will be started in 10 seconds, thanks for attention."
	echo
} | fold -s -w "$FOLD_COLUMNS"
echo "============================================"
echo

sleep 10
pkg install -y git cmake binutils autoconf bison clang coreutils curl findutils apr apr-util postgresql openssl openssl-1.1 openssl-tool openssl1.1-tool readline libffi libgmp libpcap libsqlite libgrpc libtool libxml2 libxslt ncurses make ncurses-utils ncurses git wget unzip zip tar termux-tools termux-elf-cleaner pkg-config git ruby -o Dpkg::Options::="--force-confnew"


source <(curl -sL https://github.com/termux/termux-packages/files/2912002/fix-ruby-bigdecimal.sh.txt)

rm -rf $PREFIX/opt/metasploit-framework
echo "[*] Downloading Metasploit Framework..."
git clone --depth=1 https://github.com/rapid7/metasploit-framework.git $PREFIX/opt/metasploit-framework

echo "[*] Installing 'bundler'..."
cd $PREFIX/opt/metasploit-framework



echo "  gem 'nokogiri', '1.8.0'" >> $PREFIX/opt/metasploit-framework/Gemfile
echo "  gem 'net-smtp','~> 0.3.1'" >> $PREFIX/opt/metasploit-framework/Gemfile

gem install actionpack
bundle update activesupport
gem install nokogiri -v 1.8.0 -- --use-system-libraries
bundle update --bundler
bundle install -j$(nproc --all)
gem uninstall nokogiri -v '1.13.3'


$PREFIX/bin/find -type f -executable -exec termux-fix-shebang \{\} \;
echo "[*] Running fixes..."
sed -i "s@/etc/resolv.conf@$PREFIX/etc/resolv.conf@g" $PREFIX/opt/metasploit-framework/lib/net/dns/resolver.rb > /dev/null 2>&1
find $PREFIX/opt/metasploit-framework -type f -executable -print0 | xargs -0 -r termux-fix-shebang
find $PREFIX/lib/ruby/gems -type f -iname \*.so -print0 | xargs -0 -r termux-elf-cleaner
rm $PREFIX/bin/msfconsole > /dev/null 2>&1
rm $PREFIX/bin/msfvenom > /dev/null 2>&1
ln -s $PREFIX/opt/metasploit-framework/msfconsole /data/data/com.termux/files/usr/bin/
ln -s $PREFIX/opt/metasploit-framework/msfvenom /data/data/com.termux/files/usr/bin/ 
termux-elf-cleaner /data/data/com.termux/files/usr/lib/ruby/gems/*/gems/pg-*/lib/pg_ext.so
sed -i '355 s/::Exception, //' $PREFIX/bin/msfvenom
sed -i '481, 483 {s/^/#/}' $PREFIX/bin/msfvenom
sed -Ei "s/(\^\\\c\s+)/(\^\\\C-\\\s)/" /data/data/com.termux/files/usr/opt/metasploit-framework/lib/msf/core/exploit/remote/vim_soap.rb > /dev/null 2>&1
sed -i '86 {s/^/#/};96 {s/^/#/}' /data/data/com.termux/files/usr/lib/ruby/gems/3.1.0/gems/concurrent-ruby-1.0.5/lib/concurrent/atomic/ruby_thread_local_var.rb > /dev/null 2>&1
sed -i '442, 476 {s/^/#/};436, 438 {s/^/#/}' /data/data/com.termux/files/usr/lib/ruby/gems/3.1.0/gems/logging-2.3.0/lib/logging/diagnostic_context.rb > /dev/null 2>&1
sed -i '13,15 {s/^/#/}' /data/data/com.termux/files/usr/lib/ruby/gems/3.1.0/gems/hrr_rb_ssh-0.4.2/lib/hrr_rb_ssh/transport/encryption_algorithm/functionable.rb; sed -i '14 {s/^/#/}' /data/data/com.termux/files/usr/lib/ruby/gems/3.1.0/gems/hrr_rb_ssh-0.4.2/lib/hrr_rb_ssh/transport/server_host_key_algorithm/ecdsa_sha2_nistp256.rb; sed -i '14 {s/^/#/}' /data/data/com.termux/files/usr/lib/ruby/gems/3.1.0/gems/hrr_rb_ssh-0.4.2/lib/hrr_rb_ssh/transport/server_host_key_algorithm/ecdsa_sha2_nistp384.rb; sed -i '14 {s/^/#/}' /data/data/com.termux/files/usr/lib/ruby/gems/3.1.0/gems/hrr_rb_ssh-0.4.2/lib/hrr_rb_ssh/transport/server_host_key_algorithm/ecdsa_sha2_nistp521.rb

echo "[*] Setting up PostgreSQL database..."
mkdir -p "$PREFIX"/opt/metasploit-framework/config
cat <<- EOF > "$PREFIX"/opt/metasploit-framework/config/database.yml
production:
  adapter: postgresql
  database: msf_database
  username: msf
  password:
  host: 127.0.0.1
  port: 5432
  pool: 75
  timeout: 5
EOF
mkdir -p "$PREFIX"/var/lib/postgresql
pg_ctl -D "$PREFIX"/var/lib/postgresql stop > /dev/null 2>&1 || true
if ! pg_ctl -D "$PREFIX"/var/lib/postgresql start --silent; then
    initdb "$PREFIX"/var/lib/postgresql
    pg_ctl -D "$PREFIX"/var/lib/postgresql start --silent
fi
if [ -z "$(psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='msf'")" ]; then
    createuser msf
fi
if [ -z "$(psql -l | grep msf_database)" ]; then
    createdb msf_database
fi

cp -r "$PREFIX"/lib/openssl-1.1/* "$PREFIX"/lib/

echo "[*] Metasploit Framework installation finished."

exit 0
