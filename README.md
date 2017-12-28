# slownews

A web app that aggregates best news during last week from sites like reddit and Hacker News. Uses **Haskell** for backend and **GHCJS** (via [Miso](https://haskell-miso.org)) for frontend. 

<img src="./screenshot.png" width="75%"></img>

## Running locally

First compile the frontend. This takes quite a while for GHCJS to bootstrap:

```
cd frontend && make
```

Then build the frontend:

```
cd backend && make
```

Visit http://localhost:3000/

## Deploying to Heroku


```
cd frontend && make
cd backend && make deploy
```
