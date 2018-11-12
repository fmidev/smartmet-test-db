%define DIRNAME test-db
%define LIBNAME smartmet-%{DIRNAME}
%define SPECNAME smartmet-%{DIRNAME}
Summary: Smartmet server test database contents
Name: %{SPECNAME}
Version: 18.11.12
Release: 1%{?dist}.fmi
License: MIT
Group: Development/Libraries
URL: https://github.com/fmidev/smartmet-test-db
Source: %{name}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch: noarch
BuildRequires: bzip2
BuildRequires: make
BuildRequires: rpm-build
#TestRequires: make
Provides: %{LIBNAME}
Requires: postgresql-server
Requires: postgis
Requires: bzip2

%description
FMI postgresql database contents and test data installation script.
Database is NOT automatically populated on installing this package.
Use installed script to instead.

%prep
rm -rf $RPM_BUILD_ROOT

%setup -q -n %{SPECNAME}
 
%build
make %{_smp_mflags}

%install
%makeinstall

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(0775,root,root,0775)
%{_datadir}/smartmet/test/db/*

%changelog
* Tue Oct 23 2018 Heikki Pernu <heikki.pernu@fmi.fi> - 18.10.23-1.fmi
- Packaged test data as an RPM
