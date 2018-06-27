# HUB Load

Containerized version of hub_load package provied by OPS team (joel)

## Purpose

Generates large anounts of HUB projects with versions and components.

## Usage

TBD

## Building from source

```git clone https://github.com/blackducksoftware/hub-load.git
cd hub-load/src
docker build -t <container tag> . 
```

Note: Build  process will download archives listed in hub-load/src/packagelist. This will result in a container ~5GB in size. 
