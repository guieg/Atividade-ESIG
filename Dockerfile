FROM jboss/wildfly:latest

ADD bin/jenkins.war /opt/jboss/wildfly/standalone/deployments/

