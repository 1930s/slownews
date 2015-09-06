all:	server client
	@true

server:
	go build ./src/server/

client:
	elm make src/client/SlowNews.elm --output=static/index.html

fetch:
	mkdir -p data
	./fetchnews.sh ./data
