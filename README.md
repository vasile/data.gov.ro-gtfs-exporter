# Romanian Railways GTFS exporter
This ruby utility converts public transport data from data.gov.ro into [GTFS](https://developers.google.com/transit/gtfs/reference) files. The datasource is published by the romanian railways operators at this address: https://data.gov.ro/organization/sc-informatica-feroviara-sa

## Usage
**TLDR;** If you are in a hurry just grab the gtfs files located in [gtfs-out](https://github.com/vasile/data.gov.ro-gtfs-exporter/tree/master/gtfs-out) folder of this repo. I am generating these files on a regular basis, once there is a new update from [data.gov.ro](http://data.gov.ro)

Please link back to this page if you are using this utility or the generated files in your projects. **Thanks!**.

### Steps
* clone/download this repo
* download latest XML files from [data.gov.ro](https://data.gov.ro/organization/sc-informatica-feroviara-sa) into `data.gov.ro` folder
* if needed install Nokogiri Ruby gem: `$ (sudo) gem install nokogiri`
* run `$ ruby parse.rb`
* in few seconds the `gtfs-out` folder is populated with required GTFS files

## Romanian Railways iOS App
[Romanian Railways](https://itunes.apple.com/us/app/romanian-railways/id1099755336?mt=8) is an iOS app containing all the stations and train departures in Romania, can be used offline without need of a mobile connection.

[![Romanian Railways](docs/RomanianRailwaysiOSApp.png)](https://itunes.apple.com/us/app/romanian-railways/id1099755336?mt=8)
[Download the app](https://itunes.apple.com/us/app/romanian-railways/id1099755336?mt=8)

## Romanian Railways Network
[cfr.webgis.ro](http://cfr.webgis.ro) is an example usage of using the GTFS dataset and it's a visualization of romanian railways network

[![cfr.webgis.ro](docs/RomanianRailwaysWebApp.jpeg)](http://cfr.webgis.ro)
[Click to open](http://cfr.webgis.ro)

## Contact
If you have additional questions you can use [this form](https://docs.google.com/forms/d/1ZWCqfF8OvRBlMPHMc5FbL6T3zYhQ-p18B8IIwMt1sRs/) to contact me or just ping me on [Twitter](http://twitter.com/vasile23)

**Contributors**
- Vasile Coțovanu - [@vasile](https://github.com/vasile)
- [@mbutaru](https://github.com/mbutaru)
- Alex Butum - [@mnemonicflow](https://github.com/mnemonicflow)

## License

**Copyright (c) 2016-2025 Vasile Coțovanu** - http://www.vasile.ch
 
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the **following conditions:**
 
* **The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.**
 
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
