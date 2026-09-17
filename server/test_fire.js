const fs = require('fs');
const cheerio = require('cheerio');
const html = fs.readFileSync('animefire_test.html', 'utf-8');
const $ = cheerio.load(html);
console.log('iframes:', $('iframe').length);
console.log('videos:', $('video').length);
const dataVideo = $('video').attr('data-video-src');
console.log('data-video-src:', dataVideo);
