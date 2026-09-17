const axios = require('axios');
const cheerio = require('cheerio');

async function test() {
  try {
    const res = await axios.get('https://animesorion.cc/?s=naruto', {headers: {'User-Agent': 'Mozilla/5.0'}});
    const $ = cheerio.load(res.data);
    const link = $('article a').first().attr('href');
    console.log('Link: ' + link);
    
    const res2 = await axios.get(link, {headers: {'User-Agent': 'Mozilla/5.0'}});
    const $2 = cheerio.load(res2.data);
    console.log('Episodes: ' + $2('ul.episodios li').length);
    
    const epLink = $2('ul.episodios li a').first().attr('href');
    console.log('Ep Link: ' + epLink);

    const res3 = await axios.get(epLink, {headers: {'User-Agent': 'Mozilla/5.0'}});
    const $3 = cheerio.load(res3.data);
    
    const sources = [];
    $3('ul#playeroptionsul li').each((_, el) => {
      sources.push($3(el).attr('data-post') + ' ' + $3(el).attr('data-nume') + ' ' + $3(el).attr('data-type'));
    });
    console.log('Sources: ', sources);

  } catch(e) {
    console.log('ERROR: ' + e.message);
  }
}

test();
