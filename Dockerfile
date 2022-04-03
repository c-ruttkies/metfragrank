FROM openjdk:11

WORKDIR /usr/local/bin/

ADD run.sh .

RUN chmod u+x run.sh && \
	wget https://github.com/ipb-halle/MetFragRelaunched/releases/download/v2.4.8/MetFragCommandLine-2.4.8.jar && \
	wget https://github.com/c-ruttkies/Tools/raw/master/MetFragTools-2.4.8.jar

ENTRYPOINT ["run.sh"]
