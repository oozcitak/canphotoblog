This is an easy to use photo blogging application for [node.js](http://nodejs.org/). 
Licensed under the [MIT License](http://www.opensource.org/licenses/mit-license.php).

### Installation:

First off, install `node.js` and `nginx` with your favorite package manager or build them from source. You will also need `imagemagick` and `sqlite3` installed. Then install the following node.js packages:

    npm install coffee-script
    npm install step
    npm install akismet
    npm install sqlite

The idea is to have `nginx` serve images and `node.js` to generate dynamic pages. Let's go ahead and do this. Edit your `nginx` configuration file; it should look like this:

    TODO: Add nginx conf here

Let us now clone the `canphotoblog` repository and build it:

    git clone git://github.com/oozcitak/canphotoblog.git
    cd canphotoblog
    make
    node lib/app.js

Great! Your new photo blog is now running. There aren't any pictures to look at though. Let's fix this next.

### Usage:

The application monitors the `uploads` folder for new images. To add a new image copy it into the `uploads` folder. If you copy images into a subfolder in the `uploads` folder, the subfolder name will be used as the album name, otherwise the album name will be the date the picture was taken. Go ahead and copy some images into the `uploads` folder. After a couple minutes those images should be visible.

### Administration:

You will see a `login` link at the footer of the application. Click this and login with username `admin` and password `admin`. Now click on the `admin` link on the footer and change your password. If you are using [Google Analytics](http://www.google.com/analytics/), you can enter you analytics key here. You should also register for an [Akismet](https://akismet.com/signup/) account and enter your Akismet API key here.

### Credits:

The polaroid look and advanced css effects are stolen from [Polaroids with CSS3](http://www.zurb.com/playground/css3-polaroids)