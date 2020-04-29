#!/usr/bin/perl
#
# Format of XML data from MySQL: https://dev.mysql.com/doc/refman/5.7/en/audit-log-file-formats.html#audit-log-file-new-format
# Reads audit files with XML NEW format and inserts into a reporting database.
# Will only read the file once, once fine is consumed its added in the audit_job table.
# All records are inserted into table audit_data.
#
# Make sure to import file report_schemas.sql into reporting database before running this script.
# This will create schema audit_information and tables audit_job and audit_data.
#
# TODO: Replace XML::Simple with better XML::LibXML
#
# Ted Wennmark
#

use DBI;
use CGI;
use JSON;
use File::Basename;
use XML::Simple;

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
		
		$xml = XML::Simple->new(SuppressEmpty => 1);
		$data = $xml->XMLin("$file_name_to_parse");

		foreach $info (@{$data->{AUDIT_RECORD}})
		{
			# replace tick marks ' with \' in the SQL TEXT
			# $info->{"SQLTEXT"} =~ s/'/\\'/g;
			$info->{"SQLTEXT"} =~ s/'//g;
			$qry="INSERT INTO audit_information.audit_data (COMMAND_CLASS, CONNECTIONID, DB_NAME, " .
                            "HOST_NAME, IP_ADDRESS, MYSQL_VERSION, COMMAND_NAME, OS_LOGIN, OS_VERSION, PRIV_USER, " .
                            "PROXY_USER, RECORD_ID, SERVER_ID, SQL_TEXT, STARTUP_OPTIONS, COMMAND_STATUS, " .
                            "STATUS_CODE, DATE_TIMESTAMP, USER_NAME, LOG_VERSION) values (" . 
                            "'" . $info->{"COMMAND_CLASS"} . "'," . 
                            "'" . $info->{"CONNECTION_ID"} . "'," . 
                            "'" . $info->{"DB"} . "'," . 
                            "'" . $info->{"HOST"} . "'," . 
                            "'" . $info->{"IP"} . "'," . 
                            "'" . $info->{"MYSQL_VERSION"} . "'," . 
                            "'" . $info->{"NAME"} . "'," . 
                            "'" . $info->{"OS_LOGIN"} . "'," . 
                            "'" . $info->{"OS_VERSION"} . "'," . 
                            "'" . $info->{"PRIV_USER"} . "'," . 
                            "'" . $info->{"PROXY_USER"} . "'," . 
                            "'" . $info->{"RECORD_ID"} . "'," . 
                            "'" . $info->{"SERVER_ID"} . "'," . 
                            "'" . $info->{"SQLTEXT"} . "'," . 
                            "'" . $info->{"STARTUP_OPTIONS"} . "'," . 
                            "'" . $info->{"STATUS"} . "'," . 
                            "'" . $info->{"STATUS_CODE"} . "'," . 
                            "'" . $info->{"TIMESTAMP"} . "'," . 
                            "'" . $info->{"USER"} . "'," . 
                            "'" . $info->{"VERSION"} . "')";
			# print "$qry\n";
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
