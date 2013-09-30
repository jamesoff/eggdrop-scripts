<?php
	// This is the web page for the QuoteEngine
	//
	// It goes with the QuoteEngine script for eggdrop by JamesOff
	// http://jamesoff.net
	//
	// There are a couple of things to change in the settings file
	// before this script can be used

	require("settings.inc");

	if (SETTINGS_EDITED == false) {
		die("Please edit the settings.inc file before using the script.");
	}

	if (!mysql_connect(MYSQL_HOST, MYSQL_USER, MYSQL_PASS)) {
		die("Unable to connect to database.");
	}

	if (!mysql_select_db(MYSQL_DB)) {
		die("Unable to select database.");
	}

	@mysql_set_charset('utf8');

  if (isset($_GET['channel'])) {
		$channel = $_GET['channel'];
	}
	else {
		$channel = DEFAULT_CHAN;
	}

	if (isset($_GET['remote'])) {
		$remote = $_GET['remote'];
	}

	if (isset($_GET['filter'])) {
	  $filter = $_GET['filter'];
	}

	if (isset($_GET['page'])) {
		$page = $_GET['page'];
	}

	
	if (empty($channel)) {
	  $channel = DEFAULT_CHAN;
  }

  if (!isset($remote) || empty($remote)) {
    $remote = 0;
  }

	function parse_quote($quote) {


	}

  if (!$remote) {
?>
<html>
<head>
	<title><?php
	if ($channel == "__all") {
		echo "Quotes from " . QUOTES_HOST;
	}
	else {
		echo "#" . $channel . " quotes from " . QUOTES_HOST;
	}
?></title>
		<link rel="stylesheet" type="text/css" href="<?php echo QUOTES_CSS; ?>">
		<meta http-equiv="Content-type" content="text/html; charset=UTF-8">
</head>

<?php
	}
	//check if we should be displaying all quotes from a channel
	$single_quote = "";
	if (isset($_GET['q']) && !empty($_GET['q']) && is_numeric($_GET['q'])) {
		$single_quote = mysql_real_escape_string($_GET['q']);
	}

	if ($single_quote == "") {
		//display list
		if (!$remote) {
		?>

<body>
<h1><center><?php
	if ($channel == "__all") {
		echo "All";
	}
	else {
		echo "#" . $channel;
	}
?> quotes</center></h1>
<br>
<center><form method="get" action="<?=$_SERVER['PHP_SELF'];?>">
Filter for: <input type="text" name="filter" maxlength="32" size="32"> <input type="submit" value="go"><input type="hidden" name="channel" value="<?=$channel?>">
</form>
<?php
	$result = mysql_query("SELECT DISTINCT channel FROM quotes ORDER BY channel");

  echo "<small>Other channels<br> :: ";
  while ($chan = mysql_fetch_object($result)) {
          $chanlink = preg_replace("/#(.+)/", "\\1", $chan->channel);
          echo "<a href=\"" . $_SERVER['PHP_SELF']. "?channel=$chanlink\">$chan->channel</a> :: ";
  } 
?>
		<a href="<?php echo $SERVER['PHP_SELF']; ?>?channel=__all">(All channels)</a> ::
</center>
<br><br>

Sorted with most recent first.
<?php

  }

	$chan = mysql_real_escape_string($channel);
	$filter = mysql_real_escape_string($filter);

	$channel = "#" . $channel;

	$sql = "SELECT * FROM quotes ";

	$filters = array();

	if (isset($filter) && !empty($filter)) {
		$filters[] = "quote LIKE '%" . $filter . "%'";
	}

	if ($chan != "__all") {
		$filters[] = "channel = '#" . $chan . "'";
	}

	if (sizeof($filters) > 0) {
		$sql .= "WHERE " . implode(" AND ", $filters);
	}

	$sql .= " ORDER BY timestamp DESC";

  if ($remote) {
    $sql .= " LIMIT 20";
  }

  $results = mysql_query($sql);

	if ($results && mysql_num_rows($results)) {
		$count = mysql_num_rows($results);
    if (!$remote) {
		  $quoted = array();
		  $quoter = array();
      echo "<table>";
      echo "<tr><th>#</th><th>Added by</th><th>When</th><th align=\"left\">Quote</th></tr>";
      $class = 0;
    }
    if (!empty($page)) {
      mysql_data_seek($results, $page * 100);
    }
    else {
      $page = 0;
    }
    $counter = 0;
    while (($quote = mysql_fetch_object($results)) && ($counter < 100)) {
      if (!$remote) {
        $counter++;
        echo "<tr class=\"";
        echo ($class == 0) ? "odd" : "even";
        $class = !$class;
        echo "\"><td valign=\"top\"><a name=\"$quote->id\"><a href=\"" . $PHP_SELF . "?q=$quote->id\"><small>" . $quote->id . "</small></a></td><td class=\"nick\" valign=\"top\" nowrap>";
        echo "<span title=\"" . $quote->host . "\">";
        echo $quote->nick;
				echo "</span>";
				if ($chan == "__all") {
					echo "<br><small>in " . $quote->channel . "</small>";
				}
        echo "</td>";
        echo "<td class=\"time\" valign=\"top\" nowrap><small>";
        echo date("H:i j M y", $quote->timestamp);
        echo "</small></td>";

        if (empty($quoter[$quote->nick])) {
          $quoter[$quote->nick] = 1;
        }
        else {
          $quoter[$quote->nick]++;
        }

        $quote_text = htmlentities($quote->quote);
        $quotes = @preg_split("/ \| /", $quote_text);
        $newquote = "";
        foreach ($quotes as $q) {
          $q = trim($q);
          //no timestamps
          $q = preg_replace('/^\[?[0-9:.]+\]?/', '', $q);

          //$q = preg_replace('/^((&lt;|\\[|\\()*.*?)( )(.*?(&gt;|\\]|\\))+:?)/', "\\1&nbsp;\\4", $q);
          
          //hilight nicks
          if (!preg_match("/^\* /", $q)) {
            if (preg_match('/^((&lt;|\\[|\\()*[@%+]?([^\]>\\\)]+?)[@%+]?(&gt;|\\]|\\))+:?)/', $q, $matches)) {
              if (empty($quoted[$matches[3]])) {
                $quoted[$matches[3]] = 1;
              }
              else {
                $quoted[$matches[3]] = $quoted[$matches[3]] + 1;
              }
            }
            $q = preg_replace('/^((&lt;|\\[|\\()*[^\]>\\\)]+?(&gt;|\\]|\\))+:?)/', "<b>\\1</b>", $q);
          }
          else {
            if (preg_match('/^\* [@%+]?(\S+)[@%+]?/', $q, $matches)) {
              if (empty($quoted[$matches[1]])) {
                $quoted[$matches[1]] = 1;
              }
              else {
                $quoted[$matches[1]] = $quoted[$matches[1]] + 1;
              }
            }
            $q = preg_replace('/^\* (\S+)/', "* <b>\\1</b>", $q);
          }
          //$newquote .= preg_replace('/ /', "&nbsp;", $q);
          $newquote .= $q;
          $newquote .= "<br>";
        }      
        $quote_text = preg_replace('/ \| /', "<br>", $quote_text);
        echo "<td class=\"quote\">" . $newquote . "</td>";
        echo "</tr>";
      }
      else {
        //remote
        echo $quote->quote . "\n";
      }
    }
		
    if (!$remote) {
      echo "</table>";
      echo "$count results<br>";
      if ($page > 0) {
        echo "<a href=\"" . $_SERVER['PHP_SELF'] . "?channel=$chan&filter=$filter&page=" . ($page - 1) . "\">&lt;&lt; Prev page</a>&nbsp;&nbsp";
      }
      if (($counter + ($page * 100)) < $count) {
        echo "<a href=\"" . $_SERVER['PHP_SELF'];
        echo "?channel=$chan";
        echo "&page=";
        echo ($page + 1);
        echo "&filter=$filter";
        echo "\">Next page &gt;&gt;</a>";
      }

      echo "<br><br>";
      echo "<table width=\"70%\" cellpadding=\"5\" align=\"center\">";
      echo "<tr><td valign=\"top\">";
      arsort($quoted);
      $i = 0;
      echo "<h3>Top 5 Quoted</h3>";
      echo "<small>on this page of results</small><br><br>";
      foreach($quoted as $q => $count) {
        echo "$q was quoted $count times<br>";
        if (++$i > 5) {
          break;
        }
      }
      echo "</td><td valign=\"top\">";
      echo "<h3>Top 5 Quoters</h3>";
      echo "<small>on this page of results</small><br><br>";
      arsort($quoter);
      $i = 0;
      foreach($quoter as $q => $count) {
        echo "$q added $count quotes<br>";
        if (++$i > 5) {
          break;
        }
      }
      echo "</td></tr></table>";
    }
	}
	else echo "oops: no results<br>" . mysql_error();
  
  if ($remote) {
    exit;
  }

	} //list (not quote)
	else {
		//display single quote
		$sql = "SELECT * FROM quotes WHERE id='$single_quote'";
		$result = mysql_query($sql);

		if ($result && mysql_num_rows($result)) {
			$quote = mysql_fetch_object($result);
			?>
			<div class="singlequote">
				<h1>Quote #<?=$quote->id?></h1>
				<div class="quote">
<?php
        $quote_text = htmlentities($quote->quote);
        $quotes = @preg_split("/ \| /", $quote_text);
        $newquote = "";
        foreach ($quotes as $q) {
          $q = trim($q);
          //no timestamps
          $q = preg_replace('/^\[?[0-9:.]+\]?/', '', $q);

          //$q = preg_replace('/^((&lt;|\\[|\\()*.*?)( )(.*?(&gt;|\\]|\\))+:?)/', "\\1&nbsp;\\4", $q);
          
          //hilight nicks
          if (!preg_match("/^\* /", $q)) {
            $q = preg_replace('/^((&lt;|\\[|\\()*[^\]>\\\)]+?(&gt;|\\]|\\))+:?)/', "<b>\\1</b>", $q);
          }
          else {
            $q = preg_replace('/^\* (\S+)/', "* <b>\\1</b>", $q);
          }
          $newquote .= $q;
          $newquote .= "<br>";
        }      
				?>
					<?=$newquote?><br><br>
					<div class="meta">
						Added <?=date("Y-m-d H:i:s", $quote->timestamp)?> by <?=$quote->nick?> on <?=$quote->channel?>
					</div>
				</div>
			</div>

			<?php

		}
		else {
			echo "Sorry, can't find that quote.";
		}
	}
?>
<br><br><br><br><br><br>
<center>
<a href="http://jamesoff.net/site/code/eggdrop-scripts/quoteengine/">QuoteEngine</a> by <a href="//www.jamesoff.net/">JamesOff</a> <br>
	Quotes gatered by <?php echo QUOTES_HOST; ?>
</center>

</body>
</html>
