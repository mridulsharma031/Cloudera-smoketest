#!/bin/bash
#echo "enter CM host"
#read -p "CM Host  : " CM_HOST
#read -p "User Name[used for cluster login]  : " USER
CM_HOST=`cat /etc/cloudera-scm-agent/config.ini | grep "server_host" |cut -d'=' -f2 | xargs`
USER_s=`whoami`

echo "Hello Welcome to Smoketest "
[ -d /tmp/smoketests/ ] && rm -rf /tmp/smoketests/
mkdir /tmp/smoketests/
curl -u $USER_s -k https://$CM_HOST:7183/api/v19/cm/kerberosPrincipals > /tmp/smoketests/krb_export.txt
curl -u $USER_s -k https://$CM_HOST:7183/api/v19/cm/deployment?view=EXPORT > /tmp/smoketests/cm_export.txt
while :
do
  echo "                       #################################################"
  echo "                       ####  Please enter the choice and hit Enter  ####"
  echo "                       #################################################"
  echo "                       1.   hdfs "
  echo "                       2.   impala-shell"
  echo "                       3.   hive-beeline"
  echo "                       4.   mapreduce job"
  echo "                       5.   spark submit"
  echo "                       6.   UDF Functions"
  echo "                       7.   Hive objects"
  echo "                       8.   send mail"
  echo "                       9.   Run all checks & send mail"
  echo "                      10.   Summary Result" 
  echo "                      11.   Exit"
  read INPUT_NUM
  case $INPUT_NUM in
        1)
                echo "hdfs dfs -ls /"
                hdfs dfs -ls / | tee /tmp/smoketests/hdfs_test.txt
                echo "#################################################################################################"
                ;;
        2)
                echo "impala-shell test"
                IMP_Load_b=`cat /tmp/smoketests/cm_export.txt | python -mjson.tool |  grep -A2 "impalad_load_balancer" | sed 's/"//g'|sed 's/,//g' | grep "value" | cut -d':' -f2 | awk 'NR==1{print $1}' | xargs`
                IMP_D=`cat /tmp/smoketests/krb_export.txt | python -mjson.tool | grep impala | sed 's/"//g'|sed 's/,//g' | cut -d'/' -f2 |cut -d'@' -f1 | awk 'NR==1{print $1}'`
                [[ ! -z "$IMP_Load_b" ]] && impala-shell -i $IMP_Load_b -d default -k --ssl --ca_cert=/opt/cloudera/security/pki/x509/truststore.pem -q "show databases;" | tee /tmp/smoketests/impala_test.txt || impala-shell -i $IMP_D -d default -k --ssl --ca_cert=/opt/cloudera/security/pki/x509/truststore.pem -q "show databases;" | tee /tmp/smoketests/impala_test.txt
                echo "#################################################################################################"
                ;;
        3)
                echo "hive-beeline"
                HIV_Load_b=`cat /tmp/smoketests/cm_export.txt | python -mjson.tool |  grep -A2 "hiveserver2_load_balancer" | sed 's/"//g'|sed 's/,//g' | grep "value" | cut -d':' -f2 | xargs`
                HOST_NAME=`cat /tmp/smoketests/krb_export.txt | python -mjson.tool | grep hive | sed 's/"//g'|sed 's/,//g' | cut -d'/' -f2 |cut -d'@' -f1 | awk 'NR==1{print $1}'`
                REALM=`cat /tmp/smoketests/krb_export.txt | python -mjson.tool | grep hive | sed 's/"//g'|sed 's/,//g' | cut -d'/' -f2 |cut -d'@' -f2 | awk 'NR==1{print $1}'`
                [[ ! -z "$HIV_Load_b" ]] && beeline -u "jdbc:hive2://$HIV_Load_b:10000/default;ssl=true;principal=hive/_HOST@$REALM" -e "show databases;" | tee /tmp/smoketests/hive_test.txt || beeline -u "jdbc:hive2://$HOST_NAME:10000/default;ssl=true;principal=hive/_HOST@$REALM" -e "show databases;" | tee /tmp/smoketests/hive_test.txt
                echo "#################################################################################################"
                ;;
        4)
                echo "mapreduce job"
                hadoop jar /opt/cloudera/parcels/CDH/lib/hadoop-mapreduce/hadoop-mapreduce-examples.jar pi 10 10 | tee  /tmp/smoketests/MR_test.txt
                echo "#################################################################################################"
                ;;
        5)
                echo "spark-submit"
                spark-submit --class org.apache.spark.examples.SparkPi --master yarn --deploy-mode cluster /opt/cloudera/parcels/CDH/lib/spark/examples/jars/spark-examples*.jar 10
                YARN_Appl=`yarn application -list -appStates FINISHED | grep "org.apache.spark.examples.SparkPi" | head | grep $USER_s | awk '{print $1}' | head -1 `

                yarn application -status $YARN_Appl | tee /tmp/smoketests/spark_submit_test.txt
                echo "#################################################################################################"
                ;;
        6)
                echo "impala-shell test"
                IMP_Load_b=`cat /tmp/smoketests/cm_export.txt | python -mjson.tool |  grep -A2 "impalad_load_balancer" | sed 's/"//g'|sed 's/,//g' | grep "value" | cut -d':' -f2 | awk 'NR==1{print $1}' | xargs`
                IMP_D=`cat /tmp/smoketests/krb_export.txt | python -mjson.tool | grep impala | sed 's/"//g'|sed 's/,//g' | cut -d'/' -f2 |cut -d'@' -f1 | awk 'NR==1{print $1}'`
                [[ ! -z "$IMP_Load_b" ]] && impala-shell -i $IMP_Load_b -d default -k --ssl --ca_cert=/opt/cloudera/security/pki/x509/truststore.pem -q "show databases;" | tee /tmp/smoketests/impala_test.txt || impala-shell -i $IMP_D -d default -k --ssl --ca_cert=/opt/cloudera/security/pki/x509/truststore.pem -q "show databases;" | tee /tmp/smoketests/impala_test.txt
                echo "#################################################################################################"
                ;;

        7)
                ssh $CM_HOST "sudo cat /etc/cloudera-scm-server/db.properties" >  /tmp/smoketests/db_file.txt
                DB_Host=`cat /tmp/smoketests/db_file.txt | grep "com.cloudera.cmf.db.host" | cut -d'=' -f2 | xargs`
                DB_User=`cat /tmp/smoketests/db_file.txt | grep "com.cloudera.cmf.db.user" | cut -d'=' -f2 | xargs`
                DB_Pass=`cat /tmp/smoketests/db_file.txt | grep "com.cloudera.cmf.db.password" | cut -d'=' -f2 | xargs`
                mysql -h $DB_Host -u $DB_User --password=`echo $DB_Pass` -e "SELECT OBJECT_TYPE,OBJECT_SCHEMA,OBJECT_NAME FROM (SELECT 'TABLE' AS OBJECT_TYPE,TABLE_NAME AS OBJECT_NAME,TABLE_SCHEMA AS OBJECT_SCHEMA FROM information_schema.TABLES UNION SELECT 'VIEW' AS OBJECT_TYPE,TABLE_NAME AS OBJECT_NAME,TABLE_SCHEMA AS OBJECT_SCHEMA FROM information_schema.VIEWS UNION SELECT 'INDEX[Type:Name:Table]' AS OBJECT_TYPE,CONCAT (CONSTRAINT_TYPE,' : ',CONSTRAINT_NAME,' : ',TABLE_NAME) AS OBJECT_NAME,TABLE_SCHEMA AS OBJECT_SCHEMA FROM information_schema.TABLE_CONSTRAINTS UNION SELECT ROUTINE_TYPE AS OBJECT_TYPE,ROUTINE_NAME AS OBJECT_NAME,ROUTINE_SCHEMA AS OBJECT_SCHEMA FROM information_schema.ROUTINES UNION SELECT 'TRIGGER[Schema:Object]' AS OBJECT_TYPE,CONCAT (TRIGGER_NAME,' : ',EVENT_OBJECT_SCHEMA,' : ',EVENT_OBJECT_TABLE) AS OBJECT_NAME,TRIGGER_SCHEMA AS OBJECT_SCHEMA FROM information_schema.triggers) R;"  | tee /tmp/smoketests/Hive-objects_test.txt
                echo "#################################################################################################"
                ;;

        8)
                echo "Sending mail"
                SMTP_host=`cat /tmp/smoketests/cm_export.txt | python -mjson.tool |  grep -A2 "alert_mailserver_hostname" | sed 's/"//g'|sed 's/,//g' | grep "value" | cut -d':' -f2 | xargs`
                ls /tmp/smoketests/*_test.txt >/tmp/smoketests/list
                mailx -a `pr -$(wc -l </tmp/smoketests/list) -tJS' -a ' -W1000 /tmp/smoketests/list` -S smtp=`echo $SMTP_host` -s "Smoke-tests output" -v Eamil@address < /dev/null
                ;;
        9)
                echo "Running all the tests at once & send output to mail!!!"
                echo "hdfs dfs -ls /"
                hdfs dfs -ls / | tee /tmp/smoketests/hdfs_test.txt
                echo "impala-shell test"
                IMP_Load_b=`cat /tmp/smoketests/cm_export.txt | python -mjson.tool |  grep -A2 "impalad_load_balancer" | sed 's/"//g'|sed 's/,//g' | grep "value" | cut -d':' -f2 | awk 'NR==1{print $1}' | xargs`
                IMP_D=`cat /tmp/smoketests/krb_export.txt | python -mjson.tool | grep impala | sed 's/"//g'|sed 's/,//g' | cut -d'/' -f2 |cut -d'@' -f1 | awk 'NR==1{print $1}'`
                [[ ! -z "$IMP_Load_b" ]] && impala-shell -i $IMP_Load_b -d default -k --ssl --ca_cert=/opt/cloudera/security/pki/x509/truststore.pem -q "show databases;" | tee /tmp/smoketests/impala_test.txt || impala-shell -i $IMP_D -d default -k --ssl --ca_cert=/opt/cloudera/security/pki/x509/truststore.pem -q "show databases;" | tee /tmp/smoketests/impala_test.txt
                echo "#################################################################################################"
                echo "hive-beeline"
                HIV_Load_b=`cat /tmp/smoketests/cm_export.txt | python -mjson.tool |  grep -A2 "hiveserver2_load_balancer" | sed 's/"//g'|sed 's/,//g' | grep "value" | cut -d':' -f2 | xargs`
                HOST_NAME=`cat /tmp/smoketests/krb_export.txt | python -mjson.tool | grep hive | sed 's/"//g'|sed 's/,//g' | cut -d'/' -f2 |cut -d'@' -f1 | awk 'NR==1{print $1}'`
                REALM=`cat /tmp/smoketests/krb_export.txt | python -mjson.tool | grep hive | sed 's/"//g'|sed 's/,//g' | cut -d'/' -f2 |cut -d'@' -f2 | awk 'NR==1{print $1}'`
                [[ ! -z "$HIV_Load_b" ]] && beeline -u "jdbc:hive2://$HIV_Load_b:10000/default;ssl=true;principal=hive/_HOST@$REALM" -e "show databases;" | tee /tmp/smoketests/hive_test.txt || beeline -u "jdbc:hive2://$HOST_NAME:10000/default;ssl=true;principal=hive/_HOST@$REALM" -e "show databases;" | tee /tmp/smoketests/hive_test.txt
                echo "#################################################################################################"
                echo "mapreduce job"
                hadoop jar /opt/cloudera/parcels/CDH/lib/hadoop-mapreduce/hadoop-mapreduce-examples.jar pi 10 10 | tee  /tmp/smoketests/MR_test.txt
                echo "#################################################################################################"
                echo "spark-submit"
                spark-submit --class org.apache.spark.examples.SparkPi --master yarn --deploy-mode cluster /opt/cloudera/parcels/CDH/lib/spark/examples/jars/spark-examples*.jar 10
                YARN_Appl=`yarn application -list -appStates FINISHED | grep "org.apache.spark.examples.SparkPi" | head | grep $USER_s | awk '{print $1}' | head -1 `

                yarn application -status $YARN_Appl | tee /tmp/smoketests/spark_submit_test.txt
                echo "#################################################################################################"
                echo "UDF Functions"
                echo "impala-shell test"
                IMP_Load_b=`cat /tmp/smoketests/cm_export.txt | python -mjson.tool |  grep -A2 "impalad_load_balancer" | sed 's/"//g'|sed 's/,//g' | grep "value" | cut -d':' -f2 | awk 'NR==1{print $1}' | xargs`
                IMP_D=`cat /tmp/smoketests/krb_export.txt | python -mjson.tool | grep impala | sed 's/"//g'|sed 's/,//g' | cut -d'/' -f2 |cut -d'@' -f1 | awk 'NR==1{print $1}'`
                [[ ! -z "$IMP_Load_b" ]] && impala-shell -i $IMP_Load_b -d ezpin -k --ssl --ca_cert=/opt/cloudera/security/pki/x509/truststore.pem -q "SHOW FUNCTIONS;" | tee /tmp/smoketests/UDF_test.txt || impala-shell -i $IMP_D -d ezpin -k --ssl --ca_cert=/opt/cloudera/security/pki/x509/truststore.pem -q "SHOW FUNCTIONS;" | tee /tmp/smoketests/UDF_test.txt
                echo "#################################################################################################"
                echo "Hive Objects"
                ssh $CM_HOST "sudo cat /etc/cloudera-scm-server/db.properties" >  /tmp/smoketests/db_file.txt
                DB_Host=`cat /tmp/smoketests/db_file.txt | grep "com.cloudera.cmf.db.host" | cut -d'=' -f2 | xargs`
                DB_User=`cat /tmp/smoketests/db_file.txt | grep "com.cloudera.cmf.db.user" | cut -d'=' -f2 | xargs`
                DB_Pass=`cat /tmp/smoketests/db_file.txt | grep "com.cloudera.cmf.db.password" | cut -d'=' -f2 | xargs`
                mysql -h $DB_Host -u $DB_User --password=`echo $DB_Pass` -e "SELECT OBJECT_TYPE,OBJECT_SCHEMA,OBJECT_NAME FROM (SELECT 'TABLE' AS OBJECT_TYPE,TABLE_NAME AS OBJECT_NAME,TABLE_SCHEMA AS OBJECT_SCHEMA FROM information_schema.TABLES UNION SELECT 'VIEW' AS OBJECT_TYPE,TABLE_NAME AS OBJECT_NAME,TABLE_SCHEMA AS OBJECT_SCHEMA FROM information_schema.VIEWS UNION SELECT 'INDEX[Type:Name:Table]' AS OBJECT_TYPE,CONCAT (CONSTRAINT_TYPE,' : ',CONSTRAINT_NAME,' : ',TABLE_NAME) AS OBJECT_NAME,TABLE_SCHEMA AS OBJECT_SCHEMA FROM information_schema.TABLE_CONSTRAINTS UNION SELECT ROUTINE_TYPE AS OBJECT_TYPE,ROUTINE_NAME AS OBJECT_NAME,ROUTINE_SCHEMA AS OBJECT_SCHEMA FROM information_schema.ROUTINES UNION SELECT 'TRIGGER[Schema:Object]' AS OBJECT_TYPE,CONCAT (TRIGGER_NAME,' : ',EVENT_OBJECT_SCHEMA,' : ',EVENT_OBJECT_TABLE) AS OBJECT_NAME,TRIGGER_SCHEMA AS OBJECT_SCHEMA FROM information_schema.triggers) R;"  | tee /tmp/smoketests/Hive-objects_test.txt
                echo "#################################################################################################"
                echo "Sending mail"
                SMTP_host=`cat /tmp/smoketests/cm_export.txt | python -mjson.tool |  grep -A2 "alert_mailserver_hostname" | sed 's/"//g'|sed 's/,//g' | grep "value" | cut -d':' -f2 | xargs`
                ls /tmp/smoketests/*_test.txt >/tmp/smoketests/list
                mailx -a `pr -$(wc -l </tmp/smoketests/list) -tJS' -a ' -W1000 /tmp/smoketests/list` -S smtp=`echo $SMTP_host` -s "Smoke-tests output" -v Eamil@address < /dev/null
                ;;

        10)     echo "Running all the tests at once!!!"
                echo "hdfs dfs -ls /"
                hdfs dfs -ls / > /tmp/smoketests/hdfs_test.txt
                status_hdfs=$(echo $?)
                

                IMP_Load_b=`cat /tmp/smoketests/cm_export.txt | python -mjson.tool |  grep -A2 "impalad_load_balancer" | sed 's/"//g'|sed 's/,//g' | grep "value" | cut -d':' -f2 | awk 'NR==1{print $1}' | xargs`
                IMP_D=`cat /tmp/smoketests/krb_export.txt | python -mjson.tool | grep impala | sed 's/"//g'|sed 's/,//g' | cut -d'/' -f2 |cut -d'@' -f1 | awk 'NR==1{print $1}'`
                [[ ! -z "$IMP_Load_b" ]] && impala-shell -i $IMP_Load_b -d default -k --ssl --ca_cert=/opt/cloudera/security/pki/x509/truststore.pem -q "show databases;" > /tmp/smoketests/impala_test.txt || impala-shell -i $IMP_D -d default -k --ssl --ca_cert=/opt/cloudera/security/pki/x509/truststore.pem -q "show databases;" > /tmp/smoketests/impala_test.txt
                status_imp=$(echo $?)
                

                echo "#################################################################################################"
                
                echo "hive-beeline"
                HIV_Load_b=`cat /tmp/smoketests/cm_export.txt | python -mjson.tool |  grep -A2 "hiveserver2_load_balancer" | sed 's/"//g'|sed 's/,//g' | grep "value" | cut -d':' -f2 | xargs`
                HOST_NAME=`cat /tmp/smoketests/krb_export.txt | python -mjson.tool | grep hive | sed 's/"//g'|sed 's/,//g' | cut -d'/' -f2 |cut -d'@' -f1 | awk 'NR==1{print $1}'`
                REALM=`cat /tmp/smoketests/krb_export.txt | python -mjson.tool | grep hive | sed 's/"//g'|sed 's/,//g' | cut -d'/' -f2 |cut -d'@' -f2 | awk 'NR==1{print $1}'`
                [[ ! -z "$HIV_Load_b" ]] && beeline -u "jdbc:hive2://$HIV_Load_b:10000/default;ssl=true;principal=hive/_HOST@$REALM" -e "show databases;" > /tmp/smoketests/hive_test.txt || beeline -u "jdbc:hive2://$HOST_NAME:10000/default;ssl=true;principal=hive/_HOST@$REALM" -e "show databases;" > /tmp/smoketests/hive_test.txt
                status_hive=$(echo $?)
                

                echo "#################################################################################################"
                echo "mapreduce job"
                hadoop jar /opt/cloudera/parcels/CDH/lib/hadoop-mapreduce/hadoop-mapreduce-examples.jar pi 10 10 >  /tmp/smoketests/MR_test.txt
                status_mapr=$(echo $?)
                

                echo "#################################################################################################"
                echo "spark-submit"
                spark-submit --class org.apache.spark.examples.SparkPi --master yarn --deploy-mode cluster /opt/cloudera/parcels/CDH/lib/spark/examples/jars/spark-examples*.jar 10
                status_spark=$(echo $?)
               

                YARN_Appl=`yarn application -list -appStates FINISHED | grep "org.apache.spark.examples.SparkPi" | head | grep $USER_s | awk '{print $1}' | head -1 `

                yarn application -status $YARN_Appl > /tmp/smoketests/spark_submit_test.txt
                echo "#################################################################################################"
                echo "UDF Functions"
                echo "impala-shell test"
                IMP_Load_b=`cat /tmp/smoketests/cm_export.txt | python -mjson.tool |  grep -A2 "impalad_load_balancer" | sed 's/"//g'|sed 's/,//g' | grep "value" | cut -d':' -f2 | awk 'NR==1{print $1}' | xargs`
                IMP_D=`cat /tmp/smoketests/krb_export.txt | python -mjson.tool | grep impala | sed 's/"//g'|sed 's/,//g' | cut -d'/' -f2 |cut -d'@' -f1 | awk 'NR==1{print $1}'`
                [[ ! -z "$IMP_Load_b" ]] && impala-shell -i $IMP_Load_b -d ezpin -k --ssl --ca_cert=/opt/cloudera/security/pki/x509/truststore.pem -q "SHOW FUNCTIONS;" > /tmp/smoketests/UDF_test.txt || impala-shell -i $IMP_D -d ezpin -k --ssl --ca_cert=/opt/cloudera/security/pki/x509/truststore.pem -q "SHOW FUNCTIONS;" > /tmp/smoketests/UDF_test.txt
                status_udf=$(echo $?)
               

                echo "#################################################################################################"
                echo "Hive Objects"
                ssh $CM_HOST "sudo cat /etc/cloudera-scm-server/db.properties" >  /tmp/smoketests/db_file.txt
                DB_Host=`cat /tmp/smoketests/db_file.txt | grep "com.cloudera.cmf.db.host" | cut -d'=' -f2 | xargs`
                DB_User=`cat /tmp/smoketests/db_file.txt | grep "com.cloudera.cmf.db.user" | cut -d'=' -f2 | xargs`
                DB_Pass=`cat /tmp/smoketests/db_file.txt | grep "com.cloudera.cmf.db.password" | cut -d'=' -f2 | xargs`
                mysql -h $DB_Host -u $DB_User --password=`echo $DB_Pass` -e "SELECT OBJECT_TYPE,OBJECT_SCHEMA,OBJECT_NAME FROM (SELECT 'TABLE' AS OBJECT_TYPE,TABLE_NAME AS OBJECT_NAME,TABLE_SCHEMA AS OBJECT_SCHEMA FROM information_schema.TABLES UNION SELECT 'VIEW' AS OBJECT_TYPE,TABLE_NAME AS OBJECT_NAME,TABLE_SCHEMA AS OBJECT_SCHEMA FROM information_schema.VIEWS UNION SELECT 'INDEX[Type:Name:Table]' AS OBJECT_TYPE,CONCAT (CONSTRAINT_TYPE,' : ',CONSTRAINT_NAME,' : ',TABLE_NAME) AS OBJECT_NAME,TABLE_SCHEMA AS OBJECT_SCHEMA FROM information_schema.TABLE_CONSTRAINTS UNION SELECT ROUTINE_TYPE AS OBJECT_TYPE,ROUTINE_NAME AS OBJECT_NAME,ROUTINE_SCHEMA AS OBJECT_SCHEMA FROM information_schema.ROUTINES UNION SELECT 'TRIGGER[Schema:Object]' AS OBJECT_TYPE,CONCAT (TRIGGER_NAME,' : ',EVENT_OBJECT_SCHEMA,' : ',EVENT_OBJECT_TABLE) AS OBJECT_NAME,TRIGGER_SCHEMA AS OBJECT_SCHEMA FROM information_schema.triggers) R;"  > /tmp/smoketests/Hive-objects_test.txt
                status_hobj=$(echo $?)
                

                echo "#################################################################################################"
                echo "======================================================================"
                echo "                         Sl.no   |    SERVICE     |     STATUS "
                [[ $status_hdfs -eq 0 ]] && echo "1.   |    hdfs   |   Successfull" || echo "1.   |   hdfs   |  Failed"
                [[ $status_imp -eq 0 ]] && echo "2.    |   impala  |   Successfull" || echo "2.   |  impala  |  Failed"
                [[ $status_hive -eq 0 ]] && echo "3.   |    hive   |   Successfull" || echo "3.   |   hive   |  Failed"
                [[ $status_spark -eq 0 ]] && echo "4.  |   spark   |   Successfull" || echo "4.   |  spark   |  Failed"
                [[ $status_mapr -eq 0 ]] && echo "5.   |    Mapr   |   Successfull" || echo "5.   |   Mapr   |  Failed"
                [[ $status_udf -eq 0 ]] && echo "6.    |    udf    |   Successfull" || echo "6.   |   udf    |  Failed"
                [[ $status_hobj -eq 0 ]] && echo "7.   |hive-objects|  Successfull" || echo "7.   |  hobj    |  Failed"
                echo "======================================================================" 
                
                ;;

        11)
                echo "Exiting !!!"
                exit
                ;;
        *)
                echo "Sorry !!! I didn't get you, Please enter correct choice"
                break
                ;;
  esac
done
echo
rm -rf /tmp/smoketests/

echo "########################################################################################################"
