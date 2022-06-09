#!/bin/bash

# set -xv

#--------------------
# GLOBAL VARIABLES
#--------------------
HOSTNAME=$(hostname)
HTTPS="https"
DOMAIN="env.reco.aicax"

if [[ ${HOSTNAME:0:9} == *"serveapll" ]]
then
    DIR_BASE=/jboss
    DIR_BASE=$(ls -1d ${DIR_BASE}/[0-9].[0-9].[0-9])
    DOM_BASE=domain/configuration
    DIR_TARGET=/infra/config
    DIR_LOG=/infra_pll/logs  
    opcao="App"
else
    DIR_LOG_WEB=/infra_prl/logs
    DIR_APACHE=/apache
    DIR_APACHE=$(ls -1d ${DIR_APACHE}/[0-9].[0-9].[0-9])
    opcao="Web"
fi


#------------------------------------
# Read lines from transmitted file
#------------------------------------
declare -a REGISTRY
i=0
while read line; do
        REGISTRY[$i]=$line
        (( ++i ))
done < ~/REGISTRY.txt


#--------------------------------------------------------------------
# Establish run order depending on which server is being validated
#--------------------------------------------------------------------
Main() {
    echo -n ">>>> Validating "$HOSTNAME"..." | tr 'a-z' 'A-Z'
    echo -e "\n"
   
    case $opcao in
        App) listTarget
             telnetTarget
             listLogApp
             listProperties
             listDatasource
             listNetworkConfiguration
             Report;;
             
        Web) listInstance
             telnetInstance
             listarLogApache
             listNetworkConfiguration
             VIP
             Report;;
    esac
   
    echo ">>>> Validation finished!!" | tr 'a-z' 'A-Z'
}


#-----------------------------------
# List target parameters Function
#-----------------------------------
listTarget() {
    if [[ -z "${REGISTRY[4]}" ]]
    then
        echo -e "No targets for this system\n" >> ~/Report1.txt
    else
        if [[ -d $DIR_TARGET/"${REGISTRY[0]}" ]]
        then
            VAR=$(find $DIR_TARGET/"${REGISTRY[0]}" -type f -name "*_jconnector.properties" | awk -F "/" '{print $5}')
            if [[ -f $DIR_TARGET/"${REGISTRY[0]}"/$VAR ]]
            then
                if grep -q $VAR "${DIR_BASE}/${DOM_BASE}/domain.xml";
                then
                    echo -e "Target OK!\n" >> ~/Report1.txt
                   
                    echo ">>>> Configuration in domain.xml" >> ~/Report1.txt
                    cat $DIR_BASE/$DOM_BASE/domain.xml | grep $VAR | awk -F '"' '/name/{n=$2} /value/{print n, $4}' | uniq >> ~/Report1.txt  # sed "s/name=\"\(.*\)\"|value=\"\(.*\)\" /\1/"
                    echo "" >> ~/Report1.txt
                   
                    echo ">>>> Configured targets" >> ~/Report1.txt
                    cat $DIR_TARGET/"${REGISTRY[0]}"/$VAR | awk -F "=" '/prefix/{ PREFIX=substr($1,54,9); next } /transid/{ TRANSID=$2; next } /program/{ PROGRAM=$2; next } /usr/{ USR=$2; next } /host/{ HOST=$2; next } /port/{ printf "%-10s%6s%10s%10s%24s%4s %-5d\n" , PREFIX , TRANSID , PROGRAM , USR , HOST , PORT , $2}' >> ~/Report1.txt
                   
                    cat $DIR_TARGET/"${REGISTRY[0]}"/$VAR | awk -F "=" '/host/{HOST=$2;next} /port/{print HOST, $2}' | sort | uniq >> ~/info_telnet.txt
               else
                    echo -e "Target exists, but it's not configured in domain.xml \n" >> ~/Report1.txt
                   
                    echo ">>>> Configured targets" >> ~/Report1.txt
                    cat $DIR_TARGET/"${REGISTRY[0]}"/$VAR | awk -F "=" '/prefix/{ PREFIX=substr($1,54,9); next } /transid/{ TRANSID=$2; next } /program/{ PROGRAM=$2; next } /usr/{ USR=$2; next } /host/{ HOST=$2; next } /port/{ printf "%-10s%6s%10s%10s%24s%4s %-5d\n" , PREFIX , TRANSID , PROGRAM , USR , HOST , PORT , $2}' >> ~/Report1.txt
                   
                    cat $DIR_TARGET/"${REGISTRY[0]}"/$VAR | awk -F "=" '/host/{HOST=$2;next} /port/{print HOST, $2}' | sort | uniq >> ~/info_telnet.txt
                fi
            else
                echo -e "Target file doesn't exist\n" >> ~/Report1.txt
            fi
        else
            echo -e "Target directory doesn't exist\n" >> ~/Report1.txt
        fi
    fi
}


#--------------------------
# Telnet target Function
#--------------------------
telnetTarget() {
declare -a TELNET
FILE=~/info_telnet.txt
i=0

if [[ -e "$FILE" ]]
then
    while read linha; do
        TELNET[$i]=$linha

/usr/bin/expect << EOF
set timeout 2

spawn telnet ${TELNET[$i]}
    expect {
        "Connected" {
            close
            wait
        }
        timeout {
            close
            wait
        }
    }
EOF
        (( ++i ))
    done < "$FILE"
else
    echo -e "Telnet failed, there are no targets configured.\n" >> ~/Report2.txt
fi  
   
# rm $FILE
} >> ~/Report2.txt


#------------------------------
# List Log Directory Function
#------------------------------
listLogApp() {
    if [[ -d $DIR_LOG/"${REGISTRY[0]}" ]]
    then
        LOG_APP=$(find $DIR_LOG/"${REGISTRY[0]}" -type d | awk '{print $0}')
        echo $LOG_APP >> ~/Report3.txt
        echo -e "\n"
    else
        echo -e "Log directory doesn't exist\n" >> ~/Report3.txt
    fi
}


#---------------------------------------------------------
# List Properties configurated in directory and in JBoss
#---------------------------------------------------------
listProperties() {
    if [[ -z "${REGISTRY[5]}" ]]
    then
        echo -e "Nao existe properties para este sistema\n" >> ~/Report4.txt
    else
               
        if [[ -d $DIR_TARGET/"${REGISTRY[0]}" ]]
        then    
            COUNT=$(cat ~/REGISTRY.txt | wc -l) 
            for (( i=5; i <= $COUNT - 1; ++i )) do
                VAR2=$(find $DIR_TARGET/"${REGISTRY[0]}" -type f -name "${REGISTRY[$i]}.properties" | awk -F "/" '{print $5}')
               
                if [[ -f $DIR_TARGET/"${REGISTRY[0]}"/$VAR2 && $i -ge 5 ]]
                then    
                    if grep -q $VAR2 "${DIR_BASE}/${DOM_BASE}/domain.xml";
                    then    
                        echo ">>>>>>>> Configuration in domain.xml <<<<<<<<" >> ~/Report4.txt
                        cat $DIR_BASE/$DOM_BASE/domain.xml | grep $VAR2 | awk -F '"' '/name/{n=$2} /value/{print n, $4}' | uniq >> ~/Report4.txt
                        echo "" >> ~/Report4.txt
                       
                        echo ">>>> Properties Configured" >> ~/Report4.txt
                        cat $DIR_TARGET/"${REGISTRY[0]}"/$VAR2 | sed 's/pwd=.*/pwd=/; s/senha=.*/senha=/; s/password=.*/password=/' >> ~/Report4.txt
                        echo "" >> ~/Report4.txt
                    else
                        echo ">>>>>>>> Configuration in domain.xml <<<<<<<<" >> ~/Report4.txt
                        echo -e "Configuration for properties "${REGISTRY[$i]}".properties in domain.xml doesn't exist\n" >> ~/Report4.txt
                       
                        echo -e ">>>> Relação do Propeties configurado\n" >> ~/Report4.txt
                        cat $DIR_TARGET/"${REGISTRY[0]}"/$VAR2 | sed 's/pwd=.*/pwd=/; s/senha=.*/senha=/; s/password=.*/password=/' >> ~/Report4.txt
                        echo "" >> ~/Report4.txt
                    fi
                else    
                    echo -e "Properties file "${REGISTRY[$i]}" doesn't exist\n" >> ~/Report4.txt
                fi
                   
            done < ~/REGISTRY.txt
        else
            echo -e "Properties directory doesn't exist\n" >> ~/Report4.txt
        fi
    fi
}


#----------------------------------------
# List datasources configured in JBoss
#----------------------------------------
listDatasource() {
    if grep -q "<profile name="\"${REGISTRY[0]}\"">" $DIR_BASE/$DOM_BASE/domain.xml | sed 's/^[ \t]*//';
    then
        sed -n "/<profile name="\"${REGISTRY[0]}\"">/,/<\/profile>/p" $DIR_BASE/$DOM_BASE/domain.xml|egrep 'datasource jta' |awk -F 'jndi-name=' '{print $2}' |awk '{print $1}' > ~/file1
        sed -n "/<profile name="\"${REGISTRY[0]}\"">/,/<\/profile>/p" $DIR_BASE/$DOM_BASE/domain.xml|egrep 'connection-url' |awk -F "[><]" '{print $3}' |awk 'NF > 0' > ~/file2
       
        if [[ -s file{1,2} ]]
        then
            echo "There are no datasource configured for this system in domain.xml" >> ~/Report5.txt
        else
            paste file{1,2} | column -s $'\t' -t >> ~/Report5.txt
            rm ~/file{1,2}
        fi
    else
        echo -e "The Profile for this system was not created in domain.xml\n" >> ~/Report5.txt
        return 1
    fi
}


#-------------------------------
# List Instance in vhost.conf
#-------------------------------
listInstance() {
    if [[ "${REGISTRY[3]}" == "intra" ]]
    then
        site=$(find ${DIR_APACHE}/ -type d -name $HTTPS"-"${REGISTRY[2]}"."${REGISTRY[3]}"."$DOMAIN)
    elif [[ "${REGISTRY[3]}" == "inter" ]]
    then
        site=$(find ${DIR_APACHE}/ -type d -name $HTTPS"-"${REGISTRY[2]}"."${REGISTRY[3]}"."$DOMAIN)
    else
        site=$(find ${DIR_APACHE}/ -type d -name $HTTPS"-"${REGISTRY[2]}"."$DOMAIN)
    fi

    if [[ -d $site ]]
    then
        VHOST=$(find ${site}/conf -type f -name vhost.conf)
        if [[ -f $VHOST ]]
        then
            echo ">>>> Contexts" >> ~/Report6.txt
            cat $VHOST | grep -w 'ProxyPass'| grep -i 'balancer' | awk -F "/" '{print $NF}' >> ~/Report6.txt
            echo "" >> ~/Report6.txt
       
            echo ">>>> Redirect" >> ~/Report6.txt
            cat $VHOST | grep -i RedirectMatch | awk -F ' ' '{print $NF}' >> ~/Report6.txt
            echo "" >> ~/Report6.txt
           
            echo ">>>> Document Root" >> ~/Report6.txt
            cat $VHOST | grep -i DocumentRoot | awk -F '/' '{print $6}' | sed 's,-,://,' >> ~/Report6.txt
            echo "" >> ~/Report6.txt
           
            echo ">>>> Instance" >> ~/Report6.txt
            cat $VHOST | grep -i BalancerMember | sed '/^\s*#/d' | awk -F 'route=' '{print $2}' | cut -f1 -d' ' >> ~/Report6.txt
           
            cat $VHOST | grep -i BalancerMember | sed '/^\s*#/d' | awk -F 'route=' '{print $2}' | cut -f1 -d' ' | awk -F '_' '{print $1, $NF}' >> ~/info2_telnet.txt
       
            export APP_HOSTS=$(cat $VHOST | grep -i BalancerMember | sed '/^\s*#/d' | awk -F 'route=' '{print $2}' | cut -f1 -d' '  | awk -F '_' '{print $1}' | uniq)
        else
            echo -e "vhost.conf file doesn't exist\n" >> ~/Report6.txt
        fi
    else
        echo -e "Website directory doesn't exist\n" >> ~/Report6.txt
    fi
}


#---------------------------------------------
# Telnet instances listed on listInstance()
#---------------------------------------------
telnetInstance() {
declare -a TELNET
FILE=~/info2_telnet.txt
i=0

if [[ -e "$FILE" ]]
then
    while read line; do
        TELNET[$i]=$line

/usr/bin/expect << EOF
set timeout 2

spawn telnet ${TELNET[$i]}
    expect {
        "Connected" {
            close
            wait
        }
        timeout {
            close
            wait
        }
    }
EOF
        (( ++i ))
    done < "$FILE"
else
    echo -e "Telnet failed, instances were not properly configured.\n" >> ~/Report7.txt
fi

# rm $FILE
} >> ~/Report7.txt      # | tee -a


#-----------------------------------------------------------------------------------------
# List log diretory function, apache will fail to start if the directory is not created
#-----------------------------------------------------------------------------------------
listarLogApache() {
    if [[ -z "${REGISTRY[1]}" && ( "${REGISTRY[3]}" == "intra" || "${REGISTRY[3]}" == "inter" ) ]]
    then
        site=$(find $DIR_APACHE -type d -name $HTTPS"-"${REGISTRY[2]}"."${REGISTRY[3]}"."$DOMAIN)
        if [[ -d $site ]]
        then
            VHOST=$(find "$site"/conf -type f -name vhost.conf)
            LOG_WEB=$(grep 'CustomLog' $VHOST |rev | cut -f2- -d/ |cut -f1 -d' ' |rev)
            LOG_WEB2=$(grep 'ErrorLog' $VHOST |rev | cut -f2- -d/ |cut -f1 -d' ' |rev)
        else
            echo -e "Website structure "$HTTPS"-"${REGISTRY[2]}"."${REGISTRY[3]}"."$DOMAIN" doesn't exist in this server" >> ~/Report8.txt
            return 1
        fi
       
    elif [[ -n "${REGISTRY[1]}" && ( "${REGISTRY[3]}" == "intra" || "${REGISTRY[3]}" == "inter" ) ]]
    then
        site=$(find $DIR_APACHE -type d -name $HTTPS"-"${REGISTRY[1]}"."${REGISTRY[3]}"."$DOMAIN)
        if [[ -d $site ]]
        then
            VHOST=$(find "$site"/conf -type f -name vhost.conf)
            LOG_WEB=$(grep 'CustomLog' $VHOST |rev | cut -f2- -d/ |cut -f1 -d' ' |rev)
            LOG_WEB2=$(grep 'ErrorLog' $VHOST |rev | cut -f2- -d/ |cut -f1 -d' ' |rev)
        else
            echo -e "Website structure "$HTTPS"-"${REGISTRY[1]}"."${REGISTRY[3]}"."$DOMAIN" doesn't exist in this server" >> ~/Report8.txt
            return 1
        fi
    elif [[ -z "${REGISTRY[1]}" && -z "${REGISTRY[3]}" ]]
    then
        site=$(find $DIR_APACHE -type d -name $HTTPS"-"${REGISTRY[2]}"."$DOMAIN)
        if [[ -d $site ]]
        then
            VHOST=$(find "$site"/conf -type f -name vhost.conf)
            LOG_WEB=$(grep 'CustomLog' $VHOST |rev | cut -f2- -d/ |cut -f1 -d' ' |rev)
            LOG_WEB2=$(grep 'ErrorLog' $VHOST |rev | cut -f2- -d/ |cut -f1 -d' ' |rev)
        else
            echo -e "Website structure "$HTTPS"-"${REGISTRY[2]}"."$DOMAIN" doesn't exist in this server" >> ~/Report8.txt
            return 1
        fi
   
    elif [[ -n "${REGISTRY[1]}" && -z "${REGISTRY[3]}" ]]
    then
        site=$(find $DIR_APACHE -type d -name $HTTPS"-"${REGISTRY[1]}"."$DOMAIN)
        if [[ -d $site ]]
        then
            VHOST=$(find "$site"/conf -type f -name vhost.conf)
            LOG_WEB=$(grep 'CustomLog' $VHOST |rev | cut -f2- -d/ |cut -f1 -d' ' |rev)
            LOG_WEB2=$(grep 'ErrorLog' $VHOST |rev | cut -f2- -d/ |cut -f1 -d' ' |rev)
        else
            echo -e "Website structure "$HTTPS"-"${REGISTRY[1]}"."$DOMAIN" doesn't exist in this server" >> ~/Report8.txt
            return 1
        fi  
    else
        echo -e "ERROR!!\n"
    fi

    if [[ -d $LOG_WEB && -d $LOG_WEB2 ]]
    then
        echo -e "Apache log directory: "$LOG_WEB" created and configured in vhost.conf correctly!!" >> ~/Report8.txt
    else
        echo -e "Apache log directory doesn't exist or wasn't configured correctly" >> ~/Report8.txt
    fi
}


#-------------------------------------------------------------------
# List virtual network interface in the server and in hosts file.
#-------------------------------------------------------------------
listNetworkConfiguration() {
    if [[ ${HOSTNAME:0:9} == *"serveapll" ]]
    then
        IFCONFIG=$(/sbin/ifconfig | grep -w inet |grep 10. | sed 's/^[ \t]*//')
        echo "$IFCONFIG" >> ~/Report8.txt
       
    else
        IP_HOST=$(cat /etc/hosts |grep -i "${REGISTRY[2]}" | awk -F " " '{print $1}' | uniq)
        IPS=$(/sbin/ifconfig |grep inet|awk -F ":" '{print $2}'|cut -d ' ' -f1)
        REDE=$(echo $IPS |grep -ow $IP_HOST)
       
        if [[ -z "${REGISTRY[1]}" && ( "${REGISTRY[3]}" == "intra" || "${REGISTRY[3]}" == "inter" ) ]]
        then
            NOME_HOST=$(cat /etc/hosts |grep -io ${REGISTRY[2]}"."${REGISTRY[3]}"."$DOMAIN)
       
        elif [[ -n "${REGISTRY[1]}" && ( "${REGISTRY[3]}" == "intra" || "${REGISTRY[3]}" == "inter" ) ]]
        then
            NOME_HOST=$(cat /etc/hosts |grep -io ${REGISTRY[1]}"."${REGISTRY[3]}"."$DOMAIN)
       
        elif [[ -z "${REGISTRY[1]}" && -z "${REGISTRY[3]}" ]]
        then
            NOME_HOST=$(cat /etc/hosts |grep -io ${REGISTRY[2]}"."$DOMAIN)
       
        elif [[ -n "${REGISTRY[1]}" && -z "${REGISTRY[3]}" ]]
        then
            NOME_HOST=$(cat /etc/hosts |grep -io ${REGISTRY[1]}"."$DOMAIN)
       
        else
            echo -e "Execution failed, data provided is incorrect\n" >> ~/Report9.txt
        fi
           
        if [[ -n $NOME_HOST && $REDE == $IP_HOST ]]
        then
            echo -e "IP configured in /etc/hosts: " $IP_HOST >> ~/Report9.txt
            echo -e "IP configured on virtual network interface: " $REDE >> ~/Report9.txt
            echo "" >> ~/Report9.txt
        else
            echo -e "IP configured in /etc/hosts: " $IP_HOST >> ~/Report9.txt
            echo -e "IP configured on virtual network interface: " $REDE >> ~/Report9.txt
            echo -e "Error listing network configuration, please compare the virtual network interface and /etc/hosts configuration\n" >> ~/Report9.txt
        fi
           
        INSTANCIA=$(cat /etc/hosts | grep -io $APP_HOSTS | uniq)
        IP_TELNET=$(cat ~/Report7.txt | grep -i trying | cut -f2 -d' ' | awk -F '.' '{print $1"."$2"."$3"."$4}' | uniq)
        IP_APP_HOSTS=$(cat /etc/hosts | grep -i $APP_HOSTS | awk -F " " '{print $1}' | uniq)
       
        if [[ -n $INSTANCIA && $IP_TELNET == $IP_APP_HOSTS ]]
        then
            echo -e "App IP: "$IP_APP_HOSTS" and instance "$INSTANCIA" configured correctly in hosts." >> ~/Report9.txt

        elif [[ -n $INSTANCIA &&  $IP_TELNET != $IP_APP_HOSTS ]]
        then
            echo -e "Instance: "$INSTANCIA" configured in hosts, but App IP: "$IP_APP_HOSTS" in virtual network interface is different from the IP configured in hosts." >> ~/Report9.txt
       
        elif [[ -z $INSTANCIA && $IP_TELNET == $IP_APP_HOSTS ]]
        then
            echo -e "App IP: "$IP_APP_HOSTS" configured correctly in hosts, but Instance: "$INSTANCIA" ins not configured in hosts." >> ~/Report9.txt
       
        else
            echo -e "App IP: "$IP_APP_HOSTS" and instance "$INSTANCIA" not configuraded correctly in hosts." >> ~/Report9.txt
        fi  
    fi  
}


#-------------------------------------
# List Website name and VIP address
#-------------------------------------
VIP() {
    if [[ ${REGISTRY[3]} == "intra" ]]
    then
        /usr/bin/nslookup ${REGISTRY[2]}"."${REGISTRY[3]}"."$DOMAIN|grep -A1 Name >> ~/Report10.txt
    elif [[ ${REGISTRY[3]} == "inter" ]]
    then
        /usr/bin/nslookup ${REGISTRY[2]}"."${REGISTRY[3]}"."$DOMAIN|grep -A1 Name >> ~/Report10.txt
    else
        /usr/bin/nslookup ${REGISTRY[2]}"."$DOMAIN|grep -A1 Name >> ~/Report10.txt
    fi
}


#------------------------------------------------
# Report function and remove temporarely files
#------------------------------------------------
Report() {
    if [[ $opcao == "App" ]]
    then
        echo -e "-------- $HOSTNAME" | tr 'a-z' 'A-Z' > "$HOSTNAME".txt
        echo "*************************************** Target Configuration ***************************************" | tr 'a-z' 'A-Z' >> "$HOSTNAME".txt
        cat Report1.txt >> "$HOSTNAME".txt
        echo -e "\n" >> "$HOSTNAME".txt
       
        echo "******************************************** Telnet Target ********************************************" | tr 'a-z' 'A-Z' >> "$HOSTNAME".txt
        cat Report2.txt >> "$HOSTNAME".txt
        echo -e "\n" >> "$HOSTNAME".txt
       
        echo "*********************************************** App Log ***********************************************" | tr 'a-z' 'A-Z' >> "$HOSTNAME".txt
        cat Report3.txt >> "$HOSTNAME".txt
        echo -e "\n" >> "$HOSTNAME".txt
       
        echo "************************************* Properties Configuration *************************************" | tr 'a-z' 'A-Z' >> "$HOSTNAME".txt
        cat Report4.txt >> "$HOSTNAME".txt
        echo -e "" >> "$HOSTNAME".txt
       
        echo "********************************************* Datasources *********************************************" | tr 'a-z' 'A-Z' >> "$HOSTNAME".txt
        cat Report5.txt >> "$HOSTNAME".txt
        echo -e "\n" >> "$HOSTNAME".txt
       
        echo "**************************************** Network Configuration ****************************************" | tr 'a-z' 'A-Z' >> "$HOSTNAME".txt
        cat Report8.txt >> "$HOSTNAME".txt
        echo -e "\n" >> "$HOSTNAME".txt
       
        find . -type f \( -name "*.txt" -o -name "*.sh" \) -not -name "*rjhmap*.txt" -exec rm {} \;
       
    else
       
        echo -e "-------- $HOSTNAME" | tr 'a-z' 'A-Z' > "$HOSTNAME".txt
        echo "************************************* Instance Configuration *************************************" | tr 'a-z' 'A-Z' >> "$HOSTNAME".txt
        cat Report6.txt >> "$HOSTNAME".txt
        echo -e "\n" >> "$HOSTNAME".txt
       
        echo "****************************************** Telnet Instance ******************************************" | tr 'a-z' 'A-Z' >> "$HOSTNAME".txt
        cat Report7.txt >> "$HOSTNAME".txt
        echo -e "\n" >> "$HOSTNAME".txt
       
        echo "********************************************* Apache Log *********************************************" | tr 'a-z' 'A-Z' >> "$HOSTNAME".txt
        cat Report8.txt >> "$HOSTNAME".txt
        echo -e "\n" >> "$HOSTNAME".txt
       
        echo "**************************************** Network Configuration ****************************************" | tr 'a-z' 'A-Z' >> "$HOSTNAME".txt
        cat Report9.txt >> "$HOSTNAME".txt
        echo -e "\n" >> "$HOSTNAME".txt
       
        echo "************************************************* VIP *************************************************" | tr 'a-z' 'A-Z' >> "$HOSTNAME".txt
        cat Report10.txt >> "$HOSTNAME".txt
        echo -e "\n" >> "$HOSTNAME".txt

        find . -type f \( -name "*.txt" -o -name "*.sh" \) -not -name "*rjhmap*.txt" -exec rm {} \;
    fi
}


#---------------------------
# Calling Main() Function
#---------------------------
Main
