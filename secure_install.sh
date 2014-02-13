#!/bin/bash

echo "$(tput bold ; tput setaf 6)############################################################"
echo "###	$(tput bold ; tput setaf 2) Cyklodev secure layer Ubuntu 14.04  $(tput bold ; tput setaf 6)		####"
echo "$(tput bold ; tput setaf 6)############################################################$(tput sgr0)"

echo "$(tput setaf 1)/!\ WARNING this script will enable UFW and allow only the SSH port (usually port 22).";
echo "$(tput setaf 1)Be sure to fill correctly the ssh port otherwise you will loose connection !"
echo ""

echo "$(tput bold ; tput setaf 2)Fill custom variable$(tput sgr0)"
echo "$(tput bold ; tput setaf 6)SMTP domain :$(tput sgr0)"
read SMTP_DOMAIN
echo "$(tput bold ; tput setaf 6)SMTP user :$(tput sgr0)"
read SMTP_USER
echo "$(tput bold ; tput setaf 6)SMTP password :$(tput sgr0)"
read SMTP_PASSWORD
echo "$(tput bold ; tput setaf 6)SMTP server :$(tput sgr0)"
read SMTP_SERVER
echo "$(tput bold ; tput setaf 6)Admin email for notification :$(tput sgr0)"
read ADMIN_EMAIL
echo "$(tput bold ; tput setaf 6)SSH port :$(tput sgr0)"
read SSH_PORT



if [[  "$SSH_PORT" == "" ||  "$ADMIN_EMAIL" == "" ||  "$SMTP_SERVER" == "" ||  "$SMTP_DOMAIN" == ""  || "$SMTP_USER" == ""  || "$SMTP_PASSWORD" == ""  ]]
then
	echo "$(tput setaf 1)All variables not set... exiting ...$(tput sgr0)"
	exit;
else
	echo "$(tput bold ; tput setaf 2)"
	echo "Custom variables are : "
	echo "$(tput bold ; tput setaf 4)SSH : $SSH_PORT $(tput sgr0)"
	echo "$(tput bold ; tput setaf 4)Admin email : $ADMIN_EMAIL $(tput sgr0)"
	echo "$(tput bold ; tput setaf 4)SMTP : $SMTP_SERVER $SMTP_DOMAIN $SMTP_USER $SMTP_PASSWORD $(tput sgr0)"

	read -p "$(tput bold ; tput setaf 6)Correct settings ? (y/n) $(tput sgr0)" RESP
	if [ "$RESP" = "y" ]; then
	  echo "$(tput bold ; tput setaf 2)Good continue$(tput sgr0)"
	else
	  echo "$(tput bold ; tput setaf 1)Refused by user ... exiting ...$(tput sgr0)"
	  exit
	fi


fi
echo "$(tput setaf 1)Continue $(tput sgr0)"
echo ""

echo "$(tput setaf 1)Update os$(tput sgr0)"
apt-get update
apt-get -y upgrade

echo "$(tput setaf 1)Email output settings$(tput sgr0)"

apt-get install -y ssmtp mailutils

cat <<"EOF" > /etc/ssmtp/ssmtp.conf.my
mailhub=mail
hostname=$SMTP_DOMAIN
FromLineOverride=YES
AuthUser=$SMTP_USER
AuthPass=$SMTP_PASSWORD
mailhub=$SMTP_SERVER
UseSTARTTLS=YES
EOF

cp /etc/ssmtp/ssmtp.conf /etc/ssmtp/ssmtp.conf.backup
cp /etc/ssmtp/ssmtp.conf.my /etc/ssmtp/ssmtp.conf

echo "$(tput setaf 1)Config UFW$(tput sgr0)"

ufw allow $SSH_PORT
ufw enable
ufw default deny

echo "$(tput setaf 1)Install Rkhunter$(tput sgr0)"

apt-get install -y rkhunter
echo "0 0 * * * root /usr/bin/rkhunter --update | mail -s 'Rkhunter daily Update' $ADMIN_EMAIL" >>/etc/crontab
echo "5 0 * * * root /usr/bin/rkhunter --checkall --skip-keypress | mail -s 'Rkhunter daily Scan' $ADMIN_EMAIL" >>/etc/crontab

echo "$(tput setaf 1)Install Chkrootkit$(tput sgr0)"

apt-get install -y chkrootkit

echo "10 0 * * * root /usr/bin/chkrootkit | mail -s 'Chkrootkit daily Update' $ADMIN_EMAIL" >>/etc/crontab

echo "$(tput setaf 1)Install Fail2Ban$(tput sgr0)"

apt-get install -y fail2ban

sed -i 's/mta = sendmail/mta = mail/g' /etc/fail2ban/jail.conf
sed -i "s/destemail = root@localhost/destemail = $ADMIN_EMAIL/g" /etc/fail2ban/jail.conf

fail2ban-client reload
/etc/init.d/fail2ban restart

echo "$(tput setaf 1)Install ClamAV$(tput sgr0)"
apt-get install -y clamav

echo "0 0 * * * root /usr/bin/freshclam | mail -s 'ClamAV update' $ADMIN_EMAIL" >>/etc/crontab
echo "0 1 * * * root /usr/bin/clamscan -ir / | mail -s 'ClamAV daily scan' $ADMIN_EMAIL" >>/etc/crontab

echo "$(tput setaf 1)Install LMD$(tput sgr0)"

wget www.rfxn.com/downloads/maldetect-current.tar.gz
tar xvfvz maldetect-current.tar.gz
rm -v 
cd maldetect-*
./install.sh
cd ..
rm -rfv maldetect-*

maldet -u


echo "$(tput bold ; tput setaf 6)############################################################"
echo "###	$(tput bold ; tput setaf 2) Thanks for using Cyklodev stuff ;)  $(tput bold ; tput setaf 6)		####"
echo "$(tput bold ; tput setaf 6)############################################################$(tput sgr0)"