cd curl
CPPFLAGS="-I/usr/local/ssl -I/usr/local/ssl/include" LDFLAGS="-L/usr/local/ssl/lib" LIBS="-ldl" ./configure --with-ssl --disable-shared --enable-static --disable-dict --disable-ftp --disable-imap --disable-ldap --disable-ldaps --disable-pop3 --disable-proxy --disable-rtsp --disable-smtp --disable-telnet --disable-tftp --disable-zlib --without-ca-bundle --without-gnutls --without-libidn --without-librtmp --without-libssh2 --without-nss --without-zlib
make curl_LDFLAGS=-all-static
make install curl_LDFLAGS=-all-static