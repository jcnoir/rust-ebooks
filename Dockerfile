FROM debian:8

ENV DEBIAN_FRONTEND noninteractive
ENV PATH "$PATH:/root/.cargo/bin"
ENV TRPL_PATH /trpl
ENV BOOKS_PATH $TRPL_PATH/dist

VOLUME ["/books"]

# Install all TeX and LaTeX dependences
RUN apt-get update && \
  apt-get install --yes --no-install-recommends \
  git \
  ca-certificates \
  inotify-tools \
  lmodern \
  make \
  texlive-fonts-recommended \
  texlive-generic-recommended \
  texlive-lang-english \
  texlive-lang-portuguese \
  pandoc \
  ttf-dejavu \
  fonts-ipafont \
  wget \
  xzdec \
  curl \
  build-essential \
  fonts-ipaexfont-mincho \
  texlive-xetex && \
  apt-get autoclean && apt-get --purge --yes autoremove && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install rust
RUN curl https://sh.rustup.rs -sSf > /tmp/rustup-init.sh && \
chmod +x /tmp/rustup-init.sh && \
sh /tmp/rustup-init.sh -y && \
rm -rf /tmp/rustup-init.sh

# Fetch the last book version
ENV INPUT_BOOKS /input-books
RUN mkdir $INPUT_BOOKS
WORKDIR $INPUT_BOOKS
RUN git init && \
git remote add origin 'https://github.com/rust-lang/rust.git'&& \
git config core.sparseCheckout true && \
echo "src/doc/book/src" >> .git/info/sparse-checkout && \
echo "src/doc/nomicon/src" >> .git/info/sparse-checkout && \
git pull origin master --depth 1

WORKDIR /

# Pre-build the books to make the following builds faster
RUN git clone 'https://github.com/killercup/trpl-ebook.git' "$TRPL_PATH" && \
cd $TRPL_PATH && \
cargo run --release -- --prefix=trpl --source=$INPUT_BOOKS/src/doc/book/src --meta=trpl_meta.yml && \
rm -rf /books/*

# Build the rust ebooks
CMD cd $INPUT_BOOKS && git pull --quiet --rebase origin master && cd $TRPL_PATH &&  git pull --quiet --rebase origin master && \
UPDATE_DATE=$(git log -1 --format=%cd --date=short) ; \
echo "Last book publication date: $UPDATE_DATE" ; \
sed -i "s/2016-10-01/$UPDATE_DATE/g" $TRPL_PATH/src/convert_book/options.rs && \
cd $TRPL_PATH && \
cargo run --release -- --prefix=trpl --source=$INPUT_BOOKS/src/doc/book/src --meta=trpl_meta.yml && \
cargo run --release -- --prefix=nomicon --source=$INPUT_BOOKS/src/doc/nomicon/src --meta=nomicon_meta.yml && \
cp -r $TRPL_PATH/dist/* /books && \
echo "The Rust programming ebooks have been generated in /books"
