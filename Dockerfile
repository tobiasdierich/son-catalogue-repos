FROM ruby:2.2.3-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
	build-essential && \
	apt-get -y install libcurl3 libcurl3-gnutls libcurl4-openssl-dev && \
	rm -rf /var/lib/apt/lists/*
RUN mkdir -p /app
COPY Gemfile /app/
WORKDIR /app
RUN bundle install
COPY . /app
RUN rake yard
ENV PORT 4002
#ENV MAIN_DB
#ENV MAIN_DB_HOST
#ENV SECOND_DB
#ENV SECOND_DB_HOST
EXPOSE 4002
WORKDIR /app
CMD ["rake", "start", "MAIN_DB=$MAIN_DB", "MAIN_DB_HOST=$MAIN_DB_HOST", "SECOND_DB=$SECOND_DB", "SECOND_DB_HOST=$SECOND_DB_HOST"]
