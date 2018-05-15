#!/bin/bash
set -e

# LDAP information URI
MY_LDAP_HOSTURI="{LDAP_URI}"
MY_LDAP_ROOTDN="{LDAP_ROOTDN}"
MY_LDAP_ROOTPW="{LDAP_ROOTPW}"
MY_LDAP_SEARCHBASE="{LDAP_SEARCHBASE}"
MY_LDAP_SEARCHFILTER="(&(uid=*)(objectClass=inetOrgPerson))"
MY_LDAP_SEARCHSCOPE="one"
MY_LDAP_SEARCHBIN="/usr/bin/ldapsearch"
MY_GAWK_BIN="/usr/bin/gawk"
MY_SSMTP_BIN="/usr/sbin/ssmtp"
PWD_DAYS=`expr ${PWD_MAX_AGE} - ${PWD_EXPIRE_DAY}`

# LDAP attributes storing user's information
MY_LDAP_LOGIN_ATTR=uid
MY_LDAP_MAIL_ATTR=mail

# Mail file template
MAIL_TEMPLATE="/usr/local/bin/mail.template"
MAIL_FILE="/usr/local/bin/mail.file"

# Log file
LOG_FILE=/var/log/pwdExpiredDay/pwdExpiredDay-`date "+%Y-%m-%d"`.log

# Functions - Retrieves date in seconds.
getTimeInSeconds() {
    date=0
    os=`uname -s`

    if [ "$1" ]; then
        date=`${MY_GAWK_BIN} 'BEGIN  { \
        if (ARGC == 2) { \
            print mktime(ARGV[1]) \
        } \
            exit 0 }' "$1"`
    else
        now=`date +"%Y %m %d %H %M %S" -u`
        date=`getTimeInSeconds "$now"`
    fi

    echo ${date}
}

# Variables initialization
tmp_dir="/tmp/checkldap.tmp"
result_file="${tmp_dir}/res.tmp.1"
buffer_file="${tmp_dir}/buf.tmp.1"
ldap_param="-LLL -H ${MY_LDAP_HOSTURI} -x"
nb_users=0
nb_expired_users=0
nb_mail_users=0

# Some tests
if [ -d ${tmp_dir} ]; then
    #echo "Error : temporary directory exists (${tmp_dir})"
    rm -rf ${tmp_dir}
fi
mkdir -p ${tmp_dir}

if [ ${MY_LDAP_ROOTDN} ]; then
    ldap_param="${ldap_param} -D ${MY_LDAP_ROOTDN} -w ${MY_LDAP_ROOTPW}"
fi

# Performs global search
${MY_LDAP_SEARCHBIN} ${ldap_param} -s ${MY_LDAP_SEARCHSCOPE} \
    -b "${MY_LDAP_SEARCHBASE}" "${MY_LDAP_SEARCHFILTER}" \
    "dn" > ${result_file}

# Loops on results
while read dnStr
do
    # Do not use blank lines
    if [ ! "${dnStr}" ]; then
        continue
    fi

    # Process ldap search
    dn=`echo ${dnStr} | cut -d : -f 2`

    # Increment users counter
    nb_users=`expr ${nb_users} + 1`

    ${MY_LDAP_SEARCHBIN} ${ldap_param} -s base -b "${dn}" \
        ${MY_LDAP_LOGIN_ATTR} ${MY_LDAP_MAIL_ATTR} pwdChangedTime \
        > ${buffer_file}

    login=`grep -w "${MY_LDAP_LOGIN_ATTR}:" ${buffer_file} | cut -d : -f 2 \
            | sed "s/^ *//;s/ *$//"`
    mail=`grep -w "${MY_LDAP_MAIL_ATTR}:" ${buffer_file} | cut -d : -f 2 \
            | sed "s/^ *//;s/ *$//"`
    pwdChangedTime=`grep -w "pwdChangedTime:" ${buffer_file} \
            | cut -d : -f 2 | cut -c 1-15 | sed "s/^ *//;s/ *$//"`

    # Check user's password period
    if [ "${pwdChangedTime}" ]; then
        # Retrieves time difference between today and last change.
        if [ "${pwdChangedTime}" ]; then
            s=`echo ${pwdChangedTime} | cut -c 13-14`
            m=`echo ${pwdChangedTime} | cut -c 11-12`
            h=`echo ${pwdChangedTime} | cut -c 9-10`
            d=`echo ${pwdChangedTime} | cut -c 7-8`
            M=`echo ${pwdChangedTime} | cut -c 5-6`
            y=`echo ${pwdChangedTime} | cut -c 1-4`
            currentTime=`getTimeInSeconds`
            pwdChangedTime=`getTimeInSeconds "$y $M $d $h $m $s"`
            diffTime=`expr ${currentTime} - ${pwdChangedTime}`
        fi

        # Go to next user if password already expired
        expireTime=`expr ${pwdChangedTime} + ${PWD_DAYS} \* 86400`
        if [ ${currentTime} -gt ${expireTime} ]; then
            nb_expired_users=`expr ${nb_expired_users} + 1`
            mailTime=`expr ${currentTime} - ${expireTime}`
            if [ ${mailTime} -le 86400 ]; then
                nb_mail_users=`expr ${nb_mail_users} + 1`
                # Send a message to a user who has a password expired
                rm -rf ${MAIL_FILE}
                sed -e "s|{TO_MAIL_ADDRESS}|${mail}|g" $MAIL_TEMPLATE > $MAIL_FILE
                ${MY_SSMTP_BIN} ${mail} < $MAIL_FILE
                rm -rf ${MAIL_FILE}
                continue
            fi
        fi
    fi

done < ${result_file}

# Print information to log file
echo "--- "`date +"%Y-%m-%d"`" Statistics ---" >> ${LOG_FILE}
echo "Users checked: ${nb_users}" >> ${LOG_FILE}
echo "Account expired: ${nb_expired_users}" >> ${LOG_FILE}
echo "Mail users: ${nb_mail_users}" >> ${LOG_FILE}

# Delete temporary files
rm -rf ${tmp_dir}

# Exit
exit 0
