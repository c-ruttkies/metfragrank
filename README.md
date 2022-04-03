# metfragrank
Process MetFrag parameter files and calculate rank summary

## Build

```
docker build -t metfragrank .
```

## Preparation

- create directory named 'parameters'
- place all parameter files to be processed in that directory
```
ls /data/
parameters

ls /data/parameters/
metfrag_params_1.txt  metfrag_params_2.txt  metfrag_params_3.txt  metfrag_params_4.txt
```

## Parameter files

### InChIKey

- each parameter file need a line containing the InChIKey of the correct candidate
```
# InChIKey = BSYNRYMUTXBXSQ-UHFFFAOYSA-N
```
- this InChIKey is used for ranking

### Absolute paths

- use absolute path in the parameter files
- these paths must be in the context of the Docker container

## Usage

### Processing

- run Docker container and mount root folder of your parameters directory in the container
- pass commandline option -p 'ROOT_FOLDER' 
- ROOT_FOLDER is the folder visible inside the Docker container
```
docker -v /data/metfrag:/metfrag run metfragrank -p /metfrag 
```

### Additional data

- additional data such as candidate list used for processing or peak list files need to be mounted in the Docker container
- the mount point in the Docker container needs to be set in the parameter files
```
grep PeakListPath /data/metfrag/metfrag_params_1.txt
PeakListPath = /metfrag/peaklists/metfrag_peaklists_1.txt

docker -v /data/metfrag:/metfrag -v /data/peaklists:/metfrag/peaklists run metfragrank -p /metfrag
```

### Help

- print help message by executing
```
docker run metfragrank -h
```

## Result

- Docker container prints a short ranking summary on standard out
- after processing the mount directory contains two additional folder
```
ls /data
parameters rankings results
```
- 'rankings' directory contains ranking files one for each parameter file
- 'results' contains candidate lists one for each parameter file

### Ranking file

- example of a ranking file
```
metfrag_params_1.psv BSYNRYMUTXBXSQ 2 415 57010914|0 16 22 0.99758 1.0 413.0 Score=0.9206 YIKYXZCEJLSXGO MaxScore=1.0
```
- description of columns
| Value                  | Description                                     |
| :---:                  | :---                                            |
| `metfrag_params_1.psv` | Name of result file                             |
| `BSYNRYMUTXBXSQ`       | InChIKey of ranked candidate                    |
| `2`                    | Pessimistic rank of candidate                   |
| `415`                  | Total number of candidates                      |
| `57010914|0`           | Database Identifier of candidate                |
| `16`                   | Number of explained peaks of correct candidate  |
| `22`                   | Number of peaks used for assignment in peaklist |
| `0.99758`              | Relative Ranking Position (RRP)                 |
| `1.0`                  | Number of candidates ranked better (BC)         |
| `413.0`                | Number of candidates ranked worse (WC)          |
| `Score=0.9206`         | Scores of correct candidate used for ranking    |
| `YIKYXZCEJLSXGO`       | InChIKey of candidate with maximal score        |
| `MaxScore=1.0`         | Score of best ranked candidate                  |
```
