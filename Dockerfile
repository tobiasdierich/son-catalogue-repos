FROM ruby:2.2.3-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
	build-essential && \
	rm -rf /var/lib/apt/lists/*
RUN mkdir -p /app
COPY Gemfile /app/
WORKDIR /app
RUN bundle install
COPY . /app
RUN rake yard
ENV PORT 4002
EXPOSE 4002
WORKDIR /app
CMD ["rake", "start"]
