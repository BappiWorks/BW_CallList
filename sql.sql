-- phpMyAdmin SQL Dump
-- version 4.6.6deb5
-- https://www.phpmyadmin.net/
--
-- Vært: localhost:3306
-- Genereringstid: 10. 09 2020 kl. 18:17:58
-- Serverversion: 10.4.13-MariaDB-1:10.4.13+maria~bionic-log
-- PHP-version: 7.2.24-0ubuntu0.18.04.6

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

-- --------------------------------------------------------

--
-- Struktur-dump for tabellen `BW_CallList`
--

CREATE TABLE `BW_CallList` (
  `id` int(11) NOT NULL,
  `dato` varchar(255) DEFAULT NULL,
  `message` varchar(500) DEFAULT NULL,
  `number` varchar(100) DEFAULT NULL,
  `coords` varchar(500) DEFAULT NULL,
  `service` varchar(100) NOT NULL,
  `taken` varchar(200) DEFAULT "none",
  `deleted` tinyint(1) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Indeks for tabel `BW_CallList`
--
ALTER TABLE `BW_CallList`
  ADD KEY `id` (`id`);

--
-- Tilføj AUTO_INCREMENT i tabel `BW_CallList`
--
ALTER TABLE `BW_CallList`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
