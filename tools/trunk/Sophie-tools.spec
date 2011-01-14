%define realname   Sophie-tools
%define version    0.01
%define release    %mkrel 1

Name:       Sophie-tools
Version:    %{version}
Release:    %{release}
License:    GPL or Artistic
Group:      Development/Perl
Summary:    Sophie Tools
Source:     %{realname}-%{version}.tar.gz
Url:        http://sophie.zarb.org/
BuildRoot:  %{_tmppath}/%{name}-%{version}-%{release}-buildroot
BuildArch:  noarch

BuildRequires: perl(RPC::XML::Client)

%description
Tools to query and check rpms using Sophie's website.

%prep
%setup -q -n %{realname}-%{version} 

%build
%{__perl} Makefile.PL INSTALLDIRS=vendor
%make

%check
make test

%install
rm -rf %buildroot
%makeinstall_std


%clean
rm -rf %buildroot

%files
%defattr(-,root,root)
%doc Changes README
%_bindir/*
%{_mandir}/man1/*
%{_mandir}/man3/*
%perl_vendorlib/*

