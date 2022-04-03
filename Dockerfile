FROM openjdk:8

WORKDIR /_metfrag

ADD run.sh .

RUN wget https://github.com/ipb-halle/MetFragRelaunched/releases/download/v2.4.8/MetFragCommandLine-2.4.8.jar && \
	wget https://github.com/c-ruttkies/Tools/raw/master/MetFragTools-2.4.8.jar

CMD ["run.sh"]
