#!/bin/bash
if [ ! $USE_COS ];then
	echo "USE_COS NOT ENABLE!!!!!"
else
	echo "USE_COS = $USE_COS !!!!!!!!!!!!!!"
	coscli cp /init_cos.sh cos://flink-checkpoint-1251517753/data/flink-output/${JOB_NAME}/${POD_NAME}/
	/opt/goosefs-lite-1.0.4/bin/goosefs-lite mount -o"rw,allow_other" /opt/tmp cosn://flink-checkpoint-1251517753/data/flink-output/${JOB_NAME}/${POD_NAME}
	chmod 777 /opt/tmp
fi
