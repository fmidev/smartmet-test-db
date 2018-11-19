%define DIRNAME test-db
%define LIBNAME smartmet-%{DIRNAME}
%define SPECNAME smartmet-%{DIRNAME}
Summary: Smartmet server test database contents
Name: %{SPECNAME}
Version: 18.11.19
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
#TestRequires: postgresql-server
#TestRequires: postgresql-contrib
#TestRequires: postgis
#TestRequires: bzip2
Provides: %{LIBNAME}
Requires: postgresql-contrib
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
* Mon Nov 19 2018 Heikki Pernu <heikki.pernu@fmi.fi> - 18.11.19-1.fmi
- Implement PGPORT support on scripts and add drop and stop functionality

* Wed Nov 14 2018 Heikki Pernu <heikki.pernu@fmi.fi> - 18.11.14-1.fmi
- Packaged test DB as an RPM
