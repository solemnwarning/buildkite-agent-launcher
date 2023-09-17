#!/usr/bin/perl
# Copyright 2023 Daniel Collins <solemnwarning@solemnwarning.net>
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#   Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
#   Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
#   Neither the name of the copyright holder nor the names of its contributors
#   may be used to endorse or promote products derived from this software
#   without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

use strict;
use warnings;

use Test::Spec;

use AnyEvent;
use AnyEvent::HTTP;

use FindBin;
require "$FindBin::Bin/../bin/buildkite-agent-launcher";

describe "buildkite-agent-launcher webhook server" => sub
{
	it "handles HTTP requests" => sub
	{
		my $callback_called = 0;
		
		my $server = App::BuildkiteAgentLauncher::WebhookServer->new(
			undef, # No webhook token
			sub
			{
				$callback_called = 1;
			},
			
			host => "127.0.0.1",
			port => 0);
		
		my $port = $server->port();
		
		my $cv = AnyEvent->condvar();
		http_request("POST", "http://127.0.0.1:$port/", sub
		{
			my ($body, $hdr) = @_;
			
			is($hdr->{Status}, 200);
			$cv->send();
		});
		
		$cv->recv(); # Wait for request to complete
		
		ok($callback_called);
	};
	
	it "rejects requests when token is required and not provided" => sub
	{
		my $callback_called = 0;
		
		my $server = App::BuildkiteAgentLauncher::WebhookServer->new(
			"foo",
			sub
			{
				$callback_called = 1;
			},
			
			host => "127.0.0.1",
			port => 0);
		
		my $port = $server->port();
		
		my $cv = AnyEvent->condvar();
		http_request("POST", "http://127.0.0.1:$port/", sub
		{
			my ($body, $hdr) = @_;
			
			is($hdr->{Status}, 403);
			$cv->send();
		});
		
		$cv->recv(); # Wait for request to complete
		
		ok(!$callback_called);
	};
	
	it "rejects requests when wrong token is supplied" => sub
	{
		my $callback_called = 0;
		
		my $server = App::BuildkiteAgentLauncher::WebhookServer->new(
			"foo",
			sub
			{
				$callback_called = 1;
			},
			
			host => "127.0.0.1",
			port => 0);
		
		my $port = $server->port();
		
		my $cv = AnyEvent->condvar();
		http_request("POST", "http://127.0.0.1:$port/", headers => { "X-Buildkite-Token" => "bar" }, sub
		{
			my ($body, $hdr) = @_;
			
			is($hdr->{Status}, 403);
			$cv->send();
		});
		
		$cv->recv(); # Wait for request to complete
		
		ok(!$callback_called);
	};
	
	it "rejects requests when correct token is supplied" => sub
	{
		my $callback_called = 0;
		
		my $server = App::BuildkiteAgentLauncher::WebhookServer->new(
			"foo",
			sub
			{
				$callback_called = 1;
			},
			
			host => "127.0.0.1",
			port => 0);
		
		my $port = $server->port();
		
		my $cv = AnyEvent->condvar();
		http_request("POST", "http://127.0.0.1:$port/", headers => { "X-Buildkite-Token" => "foo" }, sub
		{
			my ($body, $hdr) = @_;
			
			is($hdr->{Status}, 200);
			$cv->send();
		});
		
		$cv->recv(); # Wait for request to complete
		
		ok($callback_called);
	};
	
	it "returns 404 for unknown URLs" => sub
	{
		my $callback_called = 0;
		
		my $server = App::BuildkiteAgentLauncher::WebhookServer->new(
			"foo",
			sub
			{
				$callback_called = 1;
			},
			
			host => "127.0.0.1",
			port => 0);
		
		my $port = $server->port();
		
		my $cv = AnyEvent->condvar();
		http_request("POST", "http://127.0.0.1:$port/hello", sub
		{
			my ($body, $hdr) = @_;
			
			is($hdr->{Status}, 404);
			$cv->send();
		});
		
		$cv->recv(); # Wait for request to complete
		
		ok(!$callback_called);
	};
};

runtests unless caller;
