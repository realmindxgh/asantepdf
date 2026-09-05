# AsantePDF Third-Party Notices

AsantePDF is completely free. It uses and, in Windows release builds, may bundle open-source components whose copyrights and licenses remain with their respective authors.

This notice is a practical attribution index. Where a bundled component includes its own LICENSE, NOTICE, COPYING, README, or legal-information files, those upstream files remain authoritative and should be redistributed with that component.

## PDFium

AsantePDF uses PDFium for PDF rendering, text geometry, search, outlines and native annotation operations. PDFium is distributed under a BSD-style license. Its source tree also contains third-party components under their own licenses.

Upstream: https://pdfium.googlesource.com/pdfium/
License: https://pdfium.googlesource.com/pdfium/+/refs/heads/main/LICENSE

## PDFiumCore

AsantePDF uses the PDFiumCore .NET bindings package. PDFiumCore is published under Apache License 2.0 and packages PDFium native binaries/bindings for supported platforms.

Upstream: https://github.com/Dtronix/PDFiumCore
Package: https://www.nuget.org/packages/PDFiumCore

## qpdf

AsantePDF bundles qpdf for structural inspection, repair, page operations, security and optimization workflows. Current qpdf releases are licensed under Apache License 2.0. qpdf distributions may contain additional components with their own notices.

Upstream: https://qpdf.readthedocs.io/
License: https://qpdf.readthedocs.io/en/stable/license.html

## Tesseract OCR

AsantePDF bundles Tesseract OCR and English trained data as a local OCR fallback. Tesseract source code is licensed under Apache License 2.0. Tesseract depends on other packages, including Leptonica, that use their own open-source licenses.

Upstream: https://github.com/tesseract-ocr/tesseract
License: https://github.com/tesseract-ocr/tesseract/blob/main/LICENSE

## LibreOffice

AsantePDF release builds bundle LibreOffice for local Office-document-to-PDF conversion. LibreOffice is made available under Mozilla Public License 2.0 and includes many third-party components under additional open-source licenses. The legal files within the bundled LibreOffice installation are the authoritative detailed component notices.

Upstream licensing information: https://www.libreoffice.org/licenses/

## PDFsharp

AsantePDF uses PDFsharp-WPF for PDF construction and related document workflows. PDFsharp is published under the MIT License.

Upstream licensing information: https://docs.pdfsharp.net/General/License/License.html

## Microsoft / .NET and Windows APIs

AsantePDF is built on .NET for Windows and uses Windows platform APIs. Microsoft components are governed by the license terms that accompany the relevant .NET runtime, SDK, Windows installation, redistributables and NuGet packages.

## No transfer of third-party rights

The AsantePDF name and application code do not replace, remove, or relicense third-party copyrights. Nothing in this file grants rights beyond the terms supplied by each upstream project.
