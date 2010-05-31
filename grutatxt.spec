%define oname	grutatxt

Name:           Grutatxt
Summary:        Text to HTML converter
Version:        2.0.15
Release:	%mkrel 1
Source0:        http://triptico.com/download/%{name}-%{version}.tar.gz
URL:            http://www.triptico.com/software/grutatxt.html
Group:          Text tools
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-buildroot 
License:        GPLv2
BuildArch:	noarch

Requires:       perl


%description
Grutatxt is a plain text to HTML (and other formats) converter.
It successfully converts subtle text markup to lists, bold, italics, 
tables and headings to their corresponding HTML, troff, man page or 
LaTeX markup without having to write unreadable source text files. 
Grutatxt is a Perl module and a command line utility, 
and is the main text renderer in the Gruta CMS.


%prep 
%setup -q 

%build 
perl Makefile.PL DESTDIR=$RPM_BUILD_ROOT INSTALL_BASE=/usr SITEPREFIX=/usr INSTALLSITEMAN1DIR=%{_mandir}/man1 INSTALLSITEMAN3DIR=%{_mandir}/man3
%make

%install
rm -rf $RPM_BUILD_ROOT
%makeinstall
mkdir -p $RPM_BUILD_ROOT/%{_mandir}/man1/
install -p -m 0644 %{oname}.1* $RPM_BUILD_ROOT/%{_mandir}/man1/

%clean 
rm -rf $RPM_BUILD_ROOT 

%files 
%doc AUTHORS Changelog.1 README RELEASE_NOTES TODO doc/grutatxt_apache_handlers.txt doc/grutatxt_markup.txt
%{_bindir}/grutatxt
%{_bindir}/pod2grutatxt
%{_libdir}/perl5/Grutatxt.pm
%{_libdir}/perl5/i386-linux-thread-multi/perllocal.pod
%{_mandir}/man1/*.1*
%{_mandir}/man3/*.3*

%changelog
* Tue Mar 30 2010 Johnny A. Solbu <johnny@solbu.net> 2.0.15-1mdv
- Created specfile
