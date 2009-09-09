sub make_edit_page {
    my ($text, $mod, $tags) = @_;
    my $action_href = script_href("save", $page);

    $content .= <<"" unless $text;
  <p>
    $page doesn't exist. Why not create it by entering some text below?
  </p>

    $content .= <<"";
<form action="$action_href" method="post" enctype="application/x-www-form-urlencoded">
  <p>
    <textarea name="edittext" rows="25" cols="75">$text</textarea>
  </p>
  <p>
    Enter tags, separated by commas:<br />
    <input type="text" name="tags" value="$tags" size="75" />
  </p>
  <p>
    <input type="submit" name="submit"  value="Save" />
    <input type="reset"                 value="Revert" />
    <input type="submit" name="submit"  value="Cancel" />
    <input type="hidden" name="modtime" value="$mod" />
  </p>
</form>

    validator();
    my $edit_title = "Editing " . fancy_title($page);

    # prevent making title a link, no robots
    generate_xhtml($edit_title, $edit_title, "no");
}
