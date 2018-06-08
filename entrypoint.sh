#!/bin/bash
set -e

SSMTP_CONF="/etc/ssmtp/ssmtp.conf"
SSMTP_CUSTOM="/etc/ssmtp/ssmtp_custom.conf"
MAIL_TEMPLATE="/usr/local/bin/mail.template"
PWD_EXPIRED_DAY="/usr/local/bin/pwdExpiredDay.sh"
REWRITE_DOMAIN=${AUTH_USER#*@}

sed -i "s|{MAILHUB}|${MAILHUB}|g" $SSMTP_CUSTOM
sed -i "s|{AUTH_USER}|${AUTH_USER}|g" $SSMTP_CUSTOM
sed -i "s|{AUTH_PASS}|${AUTH_PASS}|g" $SSMTP_CUSTOM
sed -i "s|{REWRITE_DOMAIN}|${REWRITE_DOMAIN}|g" $SSMTP_CUSTOM
sed -i "s|{AUTH_USER}|${AUTH_USER}|g" $MAIL_TEMPLATE
sed -i "s|{PWD_EXPIRE_DAY}|${PWD_EXPIRE_DAY}|g" $MAIL_TEMPLATE
sed -i "s|{SSP_URL}|${SSP_URL}|g" $MAIL_TEMPLATE
sed -i "s|{TECHNICAL_SUPPORT}|${TECHNICAL_SUPPORT}|g" $MAIL_TEMPLATE
sed -i "s|{LDAP_URI}|${LDAP_URI}|g" $PWD_EXPIRED_DAY
sed -i "s|{LDAP_ROOTDN}|${LDAP_ROOTDN}|g" $PWD_EXPIRED_DAY
sed -i "s|{LDAP_ROOTPW}|${LDAP_ROOTPW}|g" $PWD_EXPIRED_DAY
sed -i "s|{LDAP_SEARCHBASE}|${LDAP_SEARCHBASE}|g" $PWD_EXPIRED_DAY
#sed -i "s|{PWD_EXPIRE_DAY}|${PWD_EXPIRE_DAY}|g" $PWD_EXPIRED_DAY

rm -f $SSMTP_CONF
cp -f $SSMTP_CUSTOM $SSMTP_CONF

exec "$@"
