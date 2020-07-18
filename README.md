# HKLUG Site Generator

This is a static html generator of the Hong Kong Linux User Group Main Site.

## Concept

No DB, No Dynamic Code, No BackEnd.

Storing the Data in Text File, using Markdown Format.
The members of the Community can add post using Github pull request, and re-generate the main site, to prevent the robot hacking of the CMS platforms.

## Structure

* TEMPLATE.txt - The Master Text File Template of the "data". Copy this file to the "data" folder and edit. Or using the script in "bin" folder to generate the new one for you.

* bin/create_announce.pl - A script to create a data file in "data/top" for announcement post.

* bin/create_post.pl - A script to create a data file in "data/news" for normal news post.

* bin/newsfeed.pl - A RSS News Feeder to grep the Posts of the RSS Feeds in the settings and auto create the data files inside "data/news" folder.

* bin/sitegen.pl - The site generator script to generate the main site by using the data in "data" folder and the HTML Template in "template" folder. And output the result in "site" folder.

* data - The data folder

* site - The main site webroot

* template - the HTML Template of the main site with Template::Toolkit format inside.

## License

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
 
