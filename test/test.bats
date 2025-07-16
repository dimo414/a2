hello_world { # @test
  echo hello there world
}

git_works { # @test
  mkdir /tmp/food
  cd /tmp/food
  git init
  git status
}
