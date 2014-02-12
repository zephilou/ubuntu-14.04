#!/bin/bash

echo "$(tput bold ; tput setaf 6)############################################################"
echo "###	$(tput bold ; tput setaf 2) Informix on  Ubuntu 14.04  $(tput bold ; tput setaf 6)			####"
echo "$(tput bold ; tput setaf 6)############################################################$(tput sgr0)"

echo "$(tput setaf 1)Update os$(tput sgr0)"
apt-get update >/dev/null
echo "$(tput setaf 1)Upgrade os$(tput sgr0)"
apt-get -y upgrade

echo "$(tput setaf 1)Check Informix archive $(tput sgr0)"

test_archive=`find . -name 'iif*.tar' | wc -l`
name_archive=`find . -name 'iif*.tar' | cut -c3-`

if [[ $test_archive -eq 1 ]]
then 
	echo "$(tput bold ; tput setaf 2) Archive here .. continue $(tput bold ; tput setaf 6)";
else
	echo "$(tput bold ; tput setaf 1) Archive not here .. put the script in same directory than Informix archive ... exiting $(tput bold ; tput setaf 6)";
	exit
fi

echo "$(tput setaf 1)Create install directory$(tput sgr0)"
mkdir /opt/informix-src
mkdir -p /opt/IBM/Informix

echo "$(tput setaf 1)Create informix user$(tput sgr0)"
useradd -d /home/informix -m informix -s /bin/bash

echo "$(tput setaf 1)Set informix password$(tput sgr0)"
passwd informix

echo "$(tput setaf 1)Uncompress Informix Archive : $(tput bold ; tput setaf 6)$name_archive $(tput sgr0)"

tar -C /opt/informix-src -xf $name_archive

echo "$(tput setaf 1)Install required packages ...$(tput sgr0)"
apt-get install -y  bc libaio1 pdksh libncurses5-dev

cat <<"EOF" > /opt/informix-src/bundle.cyklodev
LICENSE_ACCEPTED=TRUE
IDS_INSTALL_TYPE=CUSTOM
CHOSEN_FEATURE_LIST=IDS,IDS-SVR,IDS-EXT,IDS-EXT-JAVA,IDS-EXT-OPT,IDS-EXT-CNV,IDS-EXT-XML,IDS-DEMO,IDS-ER,IDS-LOAD,IDS-LOAD-ONL,IDS-LOAD-DBL,IDS-LOAD-HPL,IDS-BAR,IDS-BAR-CHK,IDS-BAR-ONBAR,IDS-BAR-TSM,IDS-ADM,IDS-ADM-PERF,IDS-ADM-MON,IDS-ADM-ADT,IDS-ADM-IMPEXP,IDS-JSON,GLS,GLS-WEURAM,GLS-EEUR,GLS-CHN,GLS-JPN,GLS-KOR,GLS-OTH,SDK,SDK-CPP,SDK-CPP-DEMO,SDK-ESQL,SDK-ESQL-DEMO,SDK-ESQL-ACM,SDK-LMI,SDK-ODBC,SDK-ODBC-DEMO,JDBC
EOF

echo "$(tput setaf 1)Launch silent install ...$(tput sgr0)"
cd /opt/informix-src/
./ids_install -i silent -f /opt/informix-src/bundle.cyklodev -DUSER_INSTALL_DIR=/opt/IBM/Informix

cp /opt/IBM/Informix/etc/onconfig.std /opt/IBM/Informix/etc/onconfig.cyklodev
cp /opt/IBM/Informix/etc/sqlhosts.std /opt/IBM/Informix/etc/sqlhosts.cyklodev

echo "$(tput setaf 1)Postconfig onconfig ...$(tput sgr0)"

sed -i 's/ROOTNAME rootdbs/ROOTNAME dbs_root/g' /opt/IBM/Informix/etc/onconfig.cyklodev 
sed -i 's/ROOTPATH $INFORMIXDIR\/tmp\/demo_on.rootdbs/ROOTPATH \/home\/informix\/spaces\/dbs_root\/dbs_root.000/g' /opt/IBM/Informix/etc/onconfig.cyklodev 
sed -i 's/CONSOLE $INFORMIXDIR\/tmp\/online.con/CONSOLE \/home\/informix\/logs\/console.log/g' /opt/IBM/Informix/etc/onconfig.cyklodev 
sed -i 's/MSGPATH $INFORMIXDIR\/tmp\/online.log/MSGPATH\/home\/informix\/logs\/online.log/g' /opt/IBM/Informix/etc/onconfig.cyklodev 
sed -i 's/DBSERVERNAME/DBSERVERNAME ol_cyklo/g' /opt/IBM/Informix/etc/onconfig.cyklodev 
sed -i 's/DEF_TABLE_LOCKMODE page/DEF_TABLE_LOCKMODE row/g' /opt/IBM/Informix/etc/onconfig.cyklodev
sed -i 's/TAPEDEV \/dev\/tapedev/TAPEDEV \/home\/informix\/backup\/datas/g' /opt/IBM/Informix/etc/onconfig.cyklodev 
sed -i 's/LTAPEDEV \/dev\/tapedev/LTAPEDEV \/home\/informix\/backup\/logs/g' /opt/IBM/Informix/etc/onconfig.cyklodev

echo "$(tput setaf 1)Postconfig sqlhost ...$(tput sgr0)"

echo "ol_cyklo        onsoctcp        *               sqlexec" >> /opt/IBM/Informix/etc/sqlhosts.cyklodev

echo "$(tput setaf 1)Include tcp support ...$(tput sgr0)"
echo 'sqlexec                  9088/tcp' >>/etc/services

echo "$(tput setaf 1)Create directory structure$(tput sgr0)"
mkdir -p /home/informix/logs
mkdir -p /home/informix/backup
mkdir -p /home/informix/backup/datas
mkdir -p /home/informix/backup/logs
mkdir -p /home/informix/spaces/dbs_root/

echo "$(tput setaf 1)Chown directory structure$(tput sgr0)"

chown informix: /home/informix/logs
chown informix: /home/informix/backup
chown informix: /home/informix/backup/datas
chown informix: /home/informix/backup/logs
chown -R informix: /home/informix/spaces

chmod -R 777 /home/informix/backup

touch /home/informix/spaces/dbs_root/dbs_root.000
chown informix: /home/informix/spaces/dbs_root/dbs_root.000
chmod 660 /home/informix/spaces/dbs_root/dbs_root.000

chown informix: /opt/IBM/Informix/etc/*.cyklodev 

echo "$(tput setaf 1)Create informix user environnement $(tput sgr0)"

cat <<"EOF" > /home/informix/ol_cyklo.env
export INFORMIXSERVER=ol_cyklo
export INFORMIXDIR="/opt/IBM/Informix"
export INFORMIXTERM=terminfo
export ONCONFIG=onconfig.cyklodev
export INFORMIXSQLHOSTS="/opt/IBM/Informix/etc/sqlhosts.cyklodev"
export CLIENT_LOCALE=en_US.utf8
export DB_LOCALE=en_US.utf8
export DBDATE=Y4MD-
export DBDELIMITER='|';
export PATH=${INFORMIXDIR}/bin:${INFORMIXDIR}/lib:${INFORMIXDIR}/lib/esql:${PATH}
export LD_LIBRARY_PATH=$INFORMIXDIR/lib:$INFORMIXDIR/lib/esql:$INFORMIXDIR/lib/tools
export PS1="IDS-12.10 CykloDev: "
export MSGPATH="/home/informix/logs/informix.log"
EOF

echo '. /home/informix/ol_cyklo.env' >>/home/informix/.bashrc

echo ""
echo ">>>	$(tput bold ; tput setaf 2) Installation complete ! You can now use Informix server$(tput sgr0)"
echo ""
echo "$(tput bold ; tput setaf 2)Switch to Informix user with :$(tput bold ; tput setaf 6) su - informix $(tput sgr0)"
echo "$(tput bold ; tput setaf 2)Initialize engine with :$(tput bold ; tput setaf 6) oninit -ivy $(tput sgr0)"
echo "$(tput bold ; tput setaf 2)Check if engine is Online with  :$(tput bold ; tput setaf 6) onstat -l $(tput sgr0)"


echo "$(tput bold ; tput setaf 6)############################################################"
echo "###	$(tput bold ; tput setaf 2) Thanks for using Cyklodev stuff ;)  $(tput bold ; tput setaf 6)		####"
echo "$(tput bold ; tput setaf 6)############################################################$(tput sgr0)"