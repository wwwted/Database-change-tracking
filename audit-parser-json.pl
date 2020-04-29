#!/usr/bin/perl
#
# Format of JSON data from MySQL: https://dev.mysql.com/doc/refman/5.7/en/audit-log-file-formats.html#audit-log-file-json-format
# Reads audit files on JSON format and inserts into a reporting database.
# Will only read the file once, once fine is consumed its added in the audit_job table.
# All records are inserted into table audit_data.
#
# Make sure to import file report_schemas.sql into reporting database before running this script.
# This will create schema audit_information and tables audit_job and audit_data.
#
# Ted Wennmark
#

use DBI;
use CGI;
use JSON;
use File::Basename;

#
# Add database connection properties and path to audit files
#

$mysql_audit_files = "/home/ted/sandboxes/MySQL-HOWTOs/mysqldata";
$mysql_host = "127.0.0.1";
$mysql_port = "8017";
$mysql_user = "msandbox";
$mysql_pwd  = "msandbox";
$db = "audit_information"; # Default value from script report_schemas.sql

#
# Do not edit below
# 

my $dbh = DBI->connect("DBI:mysql:database=$db;host=$mysql_host;port=$mysql_port",$mysql_user,$mysql_pwd,
			{'RaiseError' => 1, 'AutoCommit' => 0}) or die "\nDatabase connection error!\n" . $dbh->errstr();

@files = <$mysql_audit_files/audit.*.log>;
print "files: " . @files . "\n"; 

foreach $file_name_to_parse (@files) {
	#print "File: " . $file_name_to_parse . "\n";
        $file_name=fileparse($file_name_to_parse);
	#print $file_name . "\n";
	# check to see if audit log already been processed
        $qry = "SELECT count(*) FROM audit_jobs WHERE AUDIT_LOG_NAME = '$file_name'";
        $sth = $dbh->prepare($qry) or die "Cannot prepare: " . $dbh->errstr();
        $sth->execute() or die "Cannot execute: " . $sth->errstr();

        while (@data = $sth->fetchrow_array()) {
		$count = $data[0];
	}
        $sth->finish();

	if ( $count == 0 ) 
	{
		my $nrecs = 0;
		print "New file to consume: " . $file_name . "\n";
		
		my $json_data = do { open my $fh, '<', $file_name_to_parse; local $/; <$fh> };
		my $perl_data = decode_json $json_data;

		foreach $doc (@{$perl_data})
		{
			# replace tick marks ' with \' in the SQL TEXT
			$doc->{"general_data"}->{"query"} =~ s/'/\\'/g;
			#$doc->{"general_data"}->{"query"} =~ s/'//g;
			$qry="INSERT INTO audit_information.audit_data (COMMAND_CLASS, CONNECTIONID, DB_NAME, " .
                            "HOST_NAME, IP_ADDRESS, MYSQL_VERSION, COMMAND_NAME, OS_LOGIN, OS_VERSION, PRIV_USER, " .
                            "PROXY_USER, RECORD_ID, SERVER_ID, SQL_TEXT, STARTUP_OPTIONS, COMMAND_STATUS, " .
                            "STATUS_CODE, DATE_TIMESTAMP, USER_NAME, LOG_VERSION) values (" . 
                            "'" . $doc->{"class"} . "'," . 
                            "'" . $doc->{"connection_id"} . "'," . 
                            "'" . $doc->{"table_access_data"}->{"db"} . "'," . 
                            "'" . $doc->{"account"}->{"host"} . "'," . 
                            "'" . $doc->{"login"}->{"ip"} . "'," . 
                            "'" . $doc->{"mysql_version"} . "'," . 
                            "'" . $doc->{"general_data"}->{"command"} . "'," . 
                            "'" . $doc->{"connection_data"}->{"connection_attributes"}->{"os_user"} . "'," . 
                            "'" . $doc->{"connection_data"}->{"connection_attributes"}->{"_os"} . "'," . 
                            "'" . $doc->{"login"}->{"user"} . "'," . 
                            "'" . $doc->{"login"}->{"proxy"} . "'," . 
                            "'" . "NA" . "'," . 
                            "'" . $doc->{"startup_data"}->{"server_id"} . "'," . 
                            "'" . $doc->{"general_data"}->{"query"} . "'," . 
                            "'" . join(",", @{$r->{"startup_data"}->{"args"}}) . "'," . 
                            "'" . $doc->{"general_data"}->{"status"} . "'," . 
                            "'" . $doc->{"status"} . "'," . 
                            "'" . $doc->{"timestamp"} . "'," . 
                            "'" . $doc->{"account"}->{"user"} . "'," . 
                            "'" . "NA" . "')";
			#print "$qry\n";
                	$sth = $dbh->prepare($qry) or die "Cannot prepare: " . $dbh->errstr();
                	$sth->execute() or die "Cannot execute: " . $sth->errstr();
     		        $sth->finish();
			$nrecs++;
			if (($nrecs%100)==0) {
                		$dbh->commit() or die "commit() fail: "  . $dbh->errstr() . "\n";
			}
		}
                $dbh->commit() or die "commit() fail: "  . $dbh->errstr() . "\n";
		
		$qry = "INSERT INTO audit_information.audit_jobs (AUDIT_LOG_NAME, LOG_ENTRIES) VALUES ('$file_name', '$nrecs')";
		#print "$qry\n";
                $sth = $dbh->prepare($qry) or die "Cannot prepare: " . $dbh->errstr();
                $sth->execute() or die "Cannot execute: " . $sth->errstr();
                $dbh->commit() or die "commit() fail: "  . $dbh->errstr() . "\n";
     		$sth->finish();
	}
	else
	{
		print "File $file_name already processed\n";
	}
}

$dbh->disconnect();
exit(0);
