# $Id: en_us.pm,v 1.6 2003/02/07 22:24:34 btrott Exp $

package MT::L10N::en_us;   # American English
use strict;
use MT::L10N;
use vars qw( @ISA %Lexicon );
@ISA = qw( MT::L10N );

%Lexicon = (
    '_USAGE_REBUILD' => '<a href="#" onclick="doRebuild()">REBUILD</a> to see those changes reflected on your public site.',
    '_USAGE_VIEW_LOG' => 'Check the <a href="#" onclick="doViewLog()">Activity Log</a> for the error.',

    '_USAGE_FORGOT_PASSWORD_1' => 'You requested recovery of your Movable Type password. Your password has been changed in the system; here is the new password:',
    '_USAGE_FORGOT_PASSWORD_2' => 'You should be able to log in to Movable Type using this new password. Once you have logged in, you should change your password to something more memorable.',

    '_USAGE_BOOKMARKLET_1' => 'Setting up a bookmarklet to post to Movable Type allows you to perform one-click posting and publishing without ever entering through the main Movable Type interface.',
    '_USAGE_BOOKMARKLET_2' => 'Movable Type\'s bookmarklet structure allows you to customize the layout and fields on your bookmarklet page. For example, you may wish to add the ability to add excerpts through the bookmarklet window. By default, a bookmarklet window will always have: a pulldown menu for the weblog to post to; a pulldown menu to select the Post Status (Draft or Publish) of the new entry; a text entry box for the Title of the entry; and a text entry box for the entry body.',
    '_USAGE_BOOKMARKLET_3' => 'To install the Movable Type bookmarklet, drag the following link to your browser\'s menu or Favorites toolbar:',
    '_USAGE_BOOKMARKLET_4' => 'After installing the bookmarklet, you can post from anywhere on the web. When viewing a page that you want to post about, click the "Post to MT Weblog" bookmarklet to open a popup window with a special Movable Type editing window. From that window you can select a weblog to post the entry to, then enter you post, and publish.',
    '_USAGE_BOOKMARKLET_5' => 'Alternatively, if you are running Internet Explorer on Windows, you can install a "MT It!" option into the Windows right-click menu. Click on the link below and accept the browser prompt to "Open" the file. Then quit and restart your browser to add the link to the right-click menu.',

    '_USAGE_ARCHIVING_1' => 'Select the frequencies/types of archiving that you would like on your site. For each type of archiving that you choose, you have the option of assigning multiple Archive Templates to be applied to that particular type. For example, you might wish to create two different views of your monthly archives: one a page containing each of the entries for a particular month, and the other a calendar view of that month.', 
    '_USAGE_ARCHIVING_2' => 'When you associate multiple templates with a particular archive type--or even when you associate only one--you can customize the output path for the archive files using Archive File Templates.',
    '_USAGE_ARCHIVING_3' => 'Select the archive type to which you would like to add a new archive template. Then select the template to associate with that archive type.',

    '_USAGE_BANLIST' => 'Below is the list of IP addresses who you have banned from commenting on your site or from sending TrackBack pings to your site. To add a new IP address, enter the address in the form below. To delete a banned IP address, check the delete box in the table below, and press the DELETE button.',

    '_USAGE_PREFS' => 'This screen allows you to set a variety of optional settings concerning your blog, your archives, your comments, and your publicity &amp; notification settings. When you create a new blog, these values will be set to reasonable defaults.',

    '_USAGE_PROFILE' => 'Edit your author profile here. If you change your username or your password, your login credentials will be automatically updated. In other words, you will not need to re-login.',

    '_USAGE_CATEGORIES' => 'Use categories to group your entries for easier reference, archiving and blog display. You can assign a category to a particular entry when creating or editing entries. To change the name of an existing category, replace the old name with a new name and press save.',

    '_USAGE_COMMENT' => 'Edit the selected comment. Press SAVE when you are finished. You will need to rebuild for these changes to take effect.',

    '_USAGE_PERMISSIONS_1' => 'You are editing the permissions of <b>[_1]</b>. Below you will find a list of blogs to which you have author-editing access; for each blog in the list, assign permissions to <b>[_1]</b> by checking the boxes for the access permissions you wish to grant.',
    '_USAGE_PERMISSIONS_2' => 'To edit permissions for a different user, select a new user from the pull-down menu, then press EDIT.',
    '_USAGE_PERMISSIONS_3' => 'You have two ways to edit authors and grant/revoke access privileges. For quick access, select a user from the menu below and select edit. Alternatively, you may browse the complete list of authors and, from there, select a person to edit or delete.',
    '_USAGE_PERMISSIONS_4' => 'Each blog may have multiple authors. To add an author, enter the user\'s information in the forms below. Next, select the blogs which the author will have some sort of authoring privileges.  Once you press SAVE and the user is in the system, you can edit the author\'s privileges.',

    '_USAGE_PLACEMENTS' => 'Use the editing tools below to manage the secondary categories to which this entry is assigned. The list to the left consists of the categories to which this entry is not yet assigned as either a primary or secondary category; the list to the right consists of the secondary categories to which this entry is assigned.',

    '_USAGE_ENTRYPREFS' => 'The field configuration determines which entry fields will appear on your new and edit entry screens. You may choose an existing configuration (Basic or Advanced), or customize your screens by clicking Custom, then choosing the fields which you would like to appear.',

    '_USAGE_IMPORT' => 'Use the entry import mechanism to import your entries from another weblog content management system (Blogger or Greymatter, for example). The manual provides comprehensive instructions on importing your older entries using this mechanism; the form below lets you import a batch of entries after you have exported them from the other CMS, and have placed the exported files in the correct spot, so that Movable Type can find them. Consult the manual before using this form, to ensure that you understand all of the options.',
    '_USAGE_EXPORT_1' => 'Exporting your entries from Movable Type allows you to keep <b>personal backups</b> of your blog entries, for safekeeping. The format of the exported data is suitable for importing back into the system using the import mechanism (above); thus, in addition to exporting your entries for backup purposes, you could also use this to <b>move your content between blogs</b>.',
    '_USAGE_EXPORT_2' => 'To export your entries, click on the link below ("Export Entries From [_1]"). To save the exported data to a file, you can hold down the <code>option</code> key on the Macintosh, or the <code>Shift</code> key on a PC, while clicking on the link. Alternatively, you can select all of the data, then copy it into another document. (<a href="#" onclick="openManual(\'export_ie\')">Exporting from Internet Explorer?</a>)',
    '_USAGE_EXPORT_3' => 'Clicking the link below will export all of your current weblog entries to the Tangent server. This is generally a one-time push of your entries, to be done after you have installed the Tangent add-on for Movable Type, but conceivably it could be executed whenever you wish.',

    '_USAGE_AUTHORS' => 'This is a list of all of the users in the Movable Type system. You can edit an author\'s permissions by clicking on his/her name, and you can permanently delete authors by checking the <b>Delete</b> boxes, then pressing DELETE. NOTE: if you only want to remove an author from a particular blog, edit the author\'s permissions to remove the author; deleting an author using DELETE will remove the author from the system entirely.',

    '_USAGE_LIST_POWER' => 'Here is the list of entries for [_1] in batch-editing mode. In the form below, you may change any of the values for any of the entries displayed; after making the desired modifications, press the SAVE button. The standard List &amp; Edit Entries controls (filters, paging) work in batch mode in the manner to which you are accustomed.',
    '_USAGE_LIST' => 'Here is the list of entries for [_1]. You can edit any of these entries by clicking on the ENTRY NAME. To FILTER the entries, first select either "category", "author" or "status" from the first pull-down menu. Once that is selected, use the second pull-down menu to narrow down the choices. Use the pull-down below the entries table to adjust the amount of entries you would like to view.',

    '_USAGE_NOTIFICATIONS' => 'Here is the list of users who wish to be notified when you post to your site. To add a new user, enter their email address in the form below. The URL field is optional. To delete a user, check the delete box in the table below and press the DELETE button.',

    '_USAGE_TEMPLATES' => 'This is the list of templates that are used to construct the design and layout of your site. You can edit any of the templates from this page; in addition, you can create new index templates or delete existing index templates.',

    '_USAGE_SEARCH' => 'You can use the Search &amp; Replace tool to either search through all of your entries, or to replace every instance of one word/phrase/character with another. IMPORTANT: be careful when doing a replace, because there is <b>no undo</b>. If you are making a replacement in many of your entries, you may wish to first use the Export feature to back up your entries.',

    '_USAGE_UPLOAD' => 'You can upload the above file into either your Local Site Path <a href="javascript:alert(\'[_1]\')">(?)</a> or your Local Archive Path <a href="javascript:alert(\'[_2]\')">(?)</a>. Or, you can upload the file into any directory beneath those directories, by specifying the path in the text boxes on the right (<i>images</i>, for example). If the directory does not exist, it will be created.',

    '_AUTO' => 1,
);

1;
