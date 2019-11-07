readonly url=https://us-central1-kaito2.cloudfunctions.net/Hello

for i in {0..100}; do
    name=`sed -ne ${RANDOM}p /usr/share/dict/words`
    curl ${url}?name=${name}
done
