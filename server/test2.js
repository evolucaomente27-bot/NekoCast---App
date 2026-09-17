const axios = require('axios');
const cheerio = require('cheerio');

async function test() {
  const res = await axios.get('https://animesonlinecc.to/search/naruto', {
    headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' }
  });
  const $ = cheerio.load(res.data);
  const items = [];
  $('.result-item, article, .item').each((i, el) => {
    const title = $(el).find('h2, h3, .title, a').first().text().trim();
    if(title) {
        items.push({
        title,
        url: $(el).find('a').attr('href'),
        image: $(el).find('img').attr('src')
        });
    }
  });
  console.log(JSON.stringify(items, null, 2));
}
test();
