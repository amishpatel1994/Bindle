#!/bin/bash -vx

OOZIE_HOME_DIR=`ps -fww -u oozie | grep -oE '\-Doozie\.home\.dir=\S+' | grep -oE '/\S+'`
OOZIE_CONF_DIR=`ps -fww -u oozie | grep -oE '\-Doozie\.config\.dir=\S+' | grep -oE '/\S+'`

# Set how often (in seconds) the checking service will be run within Oozie, defaults to 60
# OOZIE_CHECK_SERVICE_PERIOD=...

# Set how often (in seconds) a particular workflow step will have its status checked, defaults to 600
# OOZIE_ACTION_RECHECK_PERIOD=...

# Set to true to emit debug logging of the oozie-sge plugin
OOZIE_SGE_DEBUG_LOG=${OOZIE_SGE_DEBUG_LOG:=true}


if [ ! -z "$OOZIE_HOME_DIR" ]; then

    if [ ! -z "$OOZIE_CONF_DIR" ]; then

        QSUB=`which qsub`

        if [ ! -z "$QSUB" ]; then

            OOZIE_WEBAPP_LIB_DIR=$OOZIE_HOME_DIR/webapps/oozie/WEB-INF/lib
            mkdir -p $OOZIE_WEBAPP_LIB_DIR
            cd $OOZIE_WEBAPP_LIB_DIR

            if type -p curl >/dev/null 2>&1; then
                HTTP_CLIENT="curl $CURL_PROXY -f -L -O"
            else
                HTTP_CLIENT="wget"
            fi

            $HTTP_CLIENT "http://wrench.res.oicr.on.ca/artifactory/seqware-dependencies/io/seqware/oozie-sge/1.0.2/oozie-sge-1.0.2.jar"
            $HTTP_CLIENT "http://repo1.maven.org/maven2/org/apache/commons/commons-exec/1.1/commons-exec-1.1.jar"
            chmod +x *.jar

            cd $OOZIE_CONF_DIR
            perl -pi -e "s/org.apache.oozie.action.email.EmailActionExecutor/io.seqware.oozie.action.sge.SgeActionExecutor,org.apache.oozie.action.email.EmailActionExecutor/;" oozie-site.xml
            perl -pi -e "s/shell-action-/sge-action-1.0.xsd,shell-action-/;" oozie-site.xml

	    # set appropriate default for maximum workflow length 
            perl -pi -e  "s/<configuration>/<configuration>\n<property><name>oozie.service.WorkflowAppService.WorkflowDefinitionMaxLength<\/name><value>10000000<\/value><\/property>/;" oozie-site.xml
	    # set appropriate default for oozie retries max
            perl -pi -e  "s/<configuration>/<configuration>\n<property><name>oozie.action.retries.max<\/name><value>30<\/value><\/property>/;" oozie-site.xml
	    # set appropriate default for oozie user-level retries max
            perl -pi -e  "s/<configuration>/<configuration>\n<property><name>oozie.service.LiteWorkflowStoreService.user.retry.max<\/name><value>30<\/value><\/property>/;" oozie-site.xml


            if [ ! -z "$OOZIE_ACTION_RECHECK_PERIOD" ]; then
               perl -pi -e  "s/<configuration>/<configuration>\n<property><name>oozie.service.ActionCheckerService.action.check.delay<\/name><value>${OOZIE_ACTION_RECHECK_PERIOD}<\/value><\/property>/;" oozie-site.xml
            else
               perl -pi -e  "s/<configuration>/<configuration>\n<property><name>oozie.service.ActionCheckerService.action.check.delay<\/name><value>10<\/value><\/property>/;" oozie-site.xml
            fi

            if [ ! -z "$OOZIE_CHECK_SERVICE_PERIOD" ]; then
                perl -pi -e  "s/<configuration>/<configuration>\n<property><name>oozie.service.ActionCheckerService.action.check.interval<\/name><value>${OOZIE_CHECK_SERVICE_PERIOD}<\/value><\/property>/;" oozie-site.xml
            else
                perl -pi -e  "s/<configuration>/<configuration>\n<property><name>oozie.service.ActionCheckerService.action.check.interval<\/name><value>5<\/value><\/property>/;" oozie-site.xml
            fi

            if $OOZIE_SGE_DEBUG_LOG; then
                echo "log4j.logger.io.seqware.oozie.action.sge=DEBUG, oozie" >> $OOZIE_CONF_DIR/oozie-log4j.properties
            fi

            echo '# Allow oozie user to qsub as other users:' >> /etc/sudoers
            echo "oozie ALL=(ALL) NOPASSWD: $QSUB" >> /etc/sudoers
            # not sure why I needed this
	    echo "oozie ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
	    echo "seqware ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

            /etc/init.d/oozie restart

        else
            echo "Path to qsub could not be resolved. Terminating."
            exit 1
        fi
     else
        echo "Oozie conf directory could not be resolved. Terminating."
        exit 1
    fi
else
    echo "Oozie webapp directory could not be resolved. Terminating."
    exit 1
fi
