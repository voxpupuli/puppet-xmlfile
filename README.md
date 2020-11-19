# Puppet XMLFile Library

[![License](https://img.shields.io/github/license/voxpupuli/puppet-xmlfile.svg)](https://github.com/voxpupuli/puppet-xmlfile/blob/master/LICENSE)

#### Table of Contents

1. [Overview - What is the xmlfile module?](#overview)
2. [Why - Reasoning for developing this module ](#why?)
3. [Implementation - Summary of the under the hood implementation of the module ](#implementation)
4. [Limitations - Known issues and limitations of the implementation ](#limitations)

## Overview

If you have ever wanted to use augeas like syntax for xml files **without the use of augeas** the xmlfile module is for you.

**NOTE** Augeas does not work on Windows.

The xmlfile type overrides the file type and inherits most of the file type attributes.
Additionally, xmlfile type will process all xmlfile_modification resources and write them out to the xmlfile without
causing resource conflicts or overwriting previously modified xml files.

Works on POSIX and Windows systems.

## Usage

To use you first must declare an xmlfile resource. You can initially set the source or content or any other type of file
based attribute.

Once the xmlfile resource is declared, you can further modify the xmlfile with the xmlfile_modification type with augeas like syntax.

```
$mq_xml_file = "/etc/activemq/activemq.conf.xml"
xmlfile { $mq_xml_file:
  ensure => present
}

xmlfile_modification { "test":
  file    => $mq_xml_file,
  changes => "set /beans/broker/transportConnectors/transportConnector[last()+1]/#attribute/name \"test\"",
  onlyif  => "match /beans/broker/transportConnectors/transportConnector[#attribute/name == \"test\"] size < 1",
}

xmlfile_modification { "test2":
  file    => $mq_xml_file,
  changes => [ "set /beans/broker/transportConnectors/transportConnector[last()+1]/#attribute/name \"tests\"",
               "set /beans/broker/transportConnectors/transportConnector[last()+1]/#attribute/value \"tests\""],
  onlyif  =>  [ "match /beans/broker/transportConnectors/transportConnector[#attribute/name == \"tests\"] size < 1" ],
}
```

## Why?

While working on a variety of modules I kept running into cases where what I really, really wanted to do was apply augeas
lenses to a template, but this was problematic. There were several options for this, none of them good. I could use a file
concat library, and sandwich augeas and file types that way, have a triggered exec resource, etc. No matter what we're basically
managing multiple resources when what we really want is just one and some changes. Just no good way to really deal with it.

My first thought was "my kingdom for an array!" which led to the databucket library, the idea behind which was to do
collection of resource parameters at catalog compilation into an array, and then use that within the template. This idea, while
cool, is, unfortunately, probably not reliable enough for production or capable of being made reliable enough for production. So
collecting and using virtual or exported data and directly referencing it(IE: in a template) is out.

Hence this, which sidetracks the whole issue.

## Implementation

By extending the Puppet file type and using some providers we can merge templated or sourced content and modifications and
have puppet treat this content as if it had been passed directly.

The changes themselves are applied via the XmlLens class, which fakes being augeas. This is accomplished via the standard
ruby REXML library. Upshot of this is we can add in things like sorting.

## Limitations

I don't have a complete Windows puppet kit and so while we extend the Windows provider and it should work, I can't actually
test it.

Property fix is called via send on object creation. This may create a security issue when a file is first created if the properties are
not correctly set, although this should get fixed on the next puppet run.

The augeas implementation is incomplete and not exact. If you notice an issue or unexpected behavior, please open an issue.

REXML has some limitations and quirks of its own. <, &, and > if by themselves will be automagically converted to
&amp;lt; &amp;amp; and &amp;gt; and there's no way to turn this off. Content is otherwise put into raw mode and so it shouldn't be
messed with.

## Authors

This module was originally forked from TERC/puppet-xmlfile. Many thanks to @cammoraton for the original work done.

- @logicminds (NWOPS, LLC) Has further refined this module.
