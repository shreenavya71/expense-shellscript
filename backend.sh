#!/bin/bash

USERID=$(id -u)
TIMESTAMP=$(date +%F-%H-%M-%S)
SCRIPT_NAME=$(echo $0 | cut -d "." -f1)
LOGFILE=/tmp/$SCRIPT_NAME-$TIMESTAMP.log
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"


VALIDATE(){
    if [ $1 -ne 0 ]
    then
        echo -e "$2 .........$R FAILURE $N"
        exit 1
    else
        echo -e "$2 .........$G SUCCESS $N"
    fi
}

if [ $USERID -ne 0 ]
then
    echo "please run this script with root access."
    exit 2       # manually exit if error comes.
else
    echo "you are super user."
fi

dnf module disable nodejs -y &>>$LOGFILE
VALIDATE $? "disabling default nodejs"

dnf module enable nodejs:20 -y &>>$LOGFILE
VALIDATE $? "Enabling nodejs:20 version"

dnf install nodejs -y &>>$LOGFILE
VALIDATE $? "Installing nodeJs"

id expense  &>>$LOGFILE                     
if [ $? -ne 0 ]
then
    useradd expense &>>$LOGFILE                            # useradd expense command is not idempotency so we are changing the code
    VALIDATE $? "creating expense user"
else   
    echo -e "Expense user already created..... $Y SKIPPING $N"
fi

mkdir -p /app &>>$LOGFILE 
VALIDATE $? "creating app directory"

curl -o /tmp/backend.zip https://expense-builds.s3.us-east-1.amazonaws.com/expense-backend-v2.zip &>>$LOGFILE 
VALIDATE $? "downloading backend code"

cd /app

unzip /tmp/backend.zip &>>$LOGFILE 
VALIDATE $? "extracted backend code"

npm install &>>$LOGFILE 
VALIDATE $? "Installing nodeJS dependencies"

cp /home/ec2-user/expense-shellscript/backend.service /etc/systemd/system/backend.service &>>$LOGFILE 
VALIDATE $? "copied backend service"


systemctl daemon-reload &>>$LOGFILE 
VALIDATE $? "Daemon Reload"

systemctl start backend &>>$LOGFILE 
VALIDATE $? "starting backend"

systemctl enable backend &>>$LOGFILE 
VALIDATE $? "Enabling Backend"

dnf install mysql -y &>>$LOGFILE 
VALIDATE $? "installing MYSQL client"

mysql -h mysql.devopsnavyahome.online -uroot -pExpenseApp@1 < /app/schema/backend.sql &>>$LOGFILE   # mysql.devopsnavyahome.online---mysql BD server ip ----configure in R53, A--record
VALIDATE $? "schema loading"

systemctl restart backend &>>$LOGFILE 
VALIDATE $? "Restarting backend"