const axios = require('axios');
const cheerio = require('cheerio');

async function test() {
  try {
    const res = await axios.get('https://animesonlinecc.to/search/naruto', {
      headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' }
    });
    const $ = cheerio.load(res.data);
    const items = [];
    $('.result-item').each((i, el) => {
      items.push({
        title: $(el).find('.title a').text(),
        url: $(el).find('.title a').attr('href'),
        image: $(el).find('img').attr('src')
      });
    });
    console.log(JSON.stringify(items, null, 2));
    
    // Now test info page
    if (items.length > 0) {
      const url = items[0].url;
      const res2 = await axios.get(url, { headers: { 'User-Agent': 'Mozilla/5.0' } });
      const $2 = cheerio.load(res2.data);
      const eps = [];
      $2('.episodios li').each((i, el) => {
        eps.push({
          id: $2(el).find('a').attr('href').split('/').pop(),
          number: $2(el).find('.numerando').text(),
          title: $2(el).find('.episodiotitle a').text()
        });
      });
      console.log("EPISODES:", JSON.stringify(eps.slice(0, 3), null, 2));
    }
  } catch(e) {
    console.error(e);
  }
}

test();
