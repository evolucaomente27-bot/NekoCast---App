const axios = require('axios');
const cheerio = require('cheerio');

async function test() {
  try {
    const res = await axios.get('https://animesorion.cc/?s=naruto', {headers: {'User-Agent': 'Mozilla/5.0'}});
    const $ = cheerio.load(res.data);
    console.log('AnimesOrion: ' + $('article').length + ' results');
  } catch(e) {
    console.log('AnimesOrion ERROR: ' + e.message);
  }

  try {
    const res2 = await axios.get('https://gogoanime3.co/search.html?keyword=naruto', {headers: {'User-Agent': 'Mozilla/5.0'}});
    const $2 = cheerio.load(res2.data);
    console.log('GogoAnime: ' + $2('.items li').length + ' results');
  } catch(e) {
    console.log('GogoAnime ERROR: ' + e.message);
  }
}

test();
