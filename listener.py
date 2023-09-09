#!/usr/bin/env python

import sys
import smtplib
import os
from email.mime.text import MIMEText
from supervisor.childutils import listener
from dotenv import load_dotenv

def write_stdout(s):
    sys.stdout.write(s)
    sys.stdout.flush()

def write_stderr(s):
    sys.stderr.write(s)
    sys.stderr.flush()

def send_email(processname, smtp_server, smtp_server_port, smtp_auth_user, smtp_auth_password, recipient):
    if not [x for x in (smtp_server, smtp_server_port, smtp_auth_user, smtp_auth_password, recipient) if x is None]:
        pass

    msg = MIMEText('Process failed: ' + processname)
    msg['Subject'] = 'Process failed: ' + processname
    msg['From'] = smtp_auth_user
    msg['To'] = recipient

    try:
       s = smtplib.SMTP(smtp_server, smtp_server_port)
       s.ehlo()
       s.starttls()
       s.login(smtp_auth_user, smtp_auth_password)
       s.sendmail(smtp_auth_user, [recipient], msg.as_string())
       s.quit()
    except SMTPException:
       write_stderr("Error: unable to send email")

if __name__ == '__main__':
    load_dotenv()
    smtp_server = os.getenv('NOTIFICATION_SMTP_SERVER')
    smtp_server_port = os.getenv('NOTIFICATION_SMTP_SERVER_PORT')
    smtp_auth_user = os.getenv('NOTIFICATION_AUTH_USER')
    smtp_auth_password = os.getenv('NOTIFICATION_AUTH_PASSWORD')
    recipient = os.getenv('NOTIFICATION_EMAIL_RECIPIENT')

    while True:
        headers, body = listener.wait(sys.stdin, sys.stdout)
        body = dict([pair.split(":") for pair in body.split(" ")])

        write_stderr("Headers: %r\n" % repr(headers))
        write_stderr("Body: %r\n" % repr(body))

        if headers["eventname"] == "PROCESS_STATE_FATAL":
            send_email(body["processname"], smtp_server, smtp_server_port, smtp_auth_user, smtp_auth_password, recipient)

        # acknowledge the event
        write_stdout("RESULT 2\nOK")