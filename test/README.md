To run tests locally use:

```shell
$ docker run -it -v "$PWD:/code" "$(docker build -q test)" /code/test
```

Currently, CI uses a [different pattern](https://github.com/bats-core/bats-action), but it may be better to use this image everywhere.