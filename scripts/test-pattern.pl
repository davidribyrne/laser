#!/usr/bin/perl
use strict;
use POSIX;


my ($header, $footer, $settings, $settingTemplate, %profiles, $elipseTemplate, $textTemplate);
my $CUT = 'Cut';
my $SCAN = 'Scan';
my $SCAN_CUT = 'Scan+Cut';
my $type = $SCAN;
my $maxSafePower = 50;
my $TEXT_INDEX = 0;
my $LINE_INDEX = 1;
my $CUT_INDEX = 2;

my $title = "1/4&quot; masked acrylic";
my @powers=(10, 15, 25, 30, 35, 40);
my @speeds=(10, 40, 100, 300, 800);
my @passCounts=(1);

my $maxRowSize = 2;
my $originX = 50;
my $originY = 50;

my $borderPadding = 2;
my $textSize = 3;
my $titleSize = $textSize + 1;
my $radius = 3;
my $gap = 1;
my $increment = $radius * 2 + $gap;
my $labelSpacing = 1;
my $verticalAxisLabelWidth = 5;
my $titleSpace = $textSize * 2 + $labelSpacing;

my $width = $borderPadding + $verticalAxisLabelWidth + $labelSpacing + $increment + $labelSpacing + scalar(@powers) * $increment + $borderPadding;
my $height = $borderPadding * 2 + $titleSpace + scalar(@speeds) * $increment +  2 * ($labelSpacing + $textSize);


main();


sub main
{
    init();


    my ($lastX, $lastY, $shapesXml);
    my $settingsXml = generateAllSettings();
#    $shapesXml .= generateRectangle($startX - $borderPadding, $startY - $borderPadding, $width, $height, 4, $TEXT_INDEX);
    my $count = scalar(@passCounts); 
    my $countX = $count >= $maxRowSize ? $maxRowSize : $count;
    my $countY = ceil($count / $maxRowSize) ;
    $shapesXml .= generateRectangle($originX, $originY, $countX * ( $width + $borderPadding * 2) , $countY * ($height + $borderPadding * 2), 4, $CUT_INDEX);

    my $startX = $originX + $borderPadding * 2;
    my $startY = $originY + $borderPadding * 2;
    my $x = $startX;
    my $y = $startY;
    my $rowCount = 1;
    for my $passCount(@passCounts)
    {
        if ($rowCount++ > $maxRowSize)
        {
            $rowCount = 0;
            $x = $startX;
            $y += $height + $borderPadding * 2;
        }
        $shapesXml .= generateGrid($x, $y, $passCount, $title);
        $x += $width + $borderPadding * 2;
    }


    my $xml = "$header\n$settingsXml\n$shapesXml\n$footer\n";
    open(my $fh, '>auto-test-pattern.lbrn2') || die "Couldn't open file for write: $!\n";
    print $fh $xml;
    close $fh;
}


sub generateGrid
{
    my ($startX, $startY, $passCount, $text) = @_;

    my $x = $startX;
    my $y = $startY + $borderPadding;
    my $shapesXml;
    $x += $width / 2;
    $shapesXml .= generateText("$text - $passCount pass" . ($passCount > 1 ? 'es' : ''), $titleSize, $x - $borderPadding, $y);
    $y += $titleSpace;

    my $firstCircleY = $y;
    $x = $startX + $borderPadding;
    $y += $increment * (scalar(@speeds) - 1) /2;
    $shapesXml .= generateText("Speed (mm/s)", $textSize, $x, $y, 1);

    $x += $verticalAxisLabelWidth + $labelSpacing;
    
    $y = $firstCircleY;
    for my $speed(@speeds)
    {
        $shapesXml .= generateText("$speed", $textSize, $x, $y);
        $y += $increment;
    }

    $x += $increment + $labelSpacing;
    my $firstCircleX = $x;
    for my $power(@powers)
    {
        my $type = $SCAN_CUT;
        my $y = $firstCircleY;
        for my $speed(@speeds)
        {
            die "Too powerful: $power\n" if $power > 60;
            my $scale = int(100 * $power/$maxSafePower);
            die "Excessive scale ($scale) for speed $speed and power $power\n" if $scale > 100;

            my $settingsIndex = $profiles{$speed}{$passCount} || die "Couldn't find settings index for $speed $passCount\n";
            $shapesXml .= generateElipse($settingsIndex, $scale, $radius, $radius, $x, $y);
            $y += $increment;
        }
        $x += $increment;
    }

    $y -= 1;
    $x = $firstCircleX;
    for my $power(@powers)
    {
        $shapesXml .= generateText($power, $textSize, $x, $y);
        $x += $increment;
    }

    $y += $textSize + 1;
    my $count = scalar(@powers);
    $x = $firstCircleX + $increment * (scalar(@powers) - 1) / 2;

    
    $shapesXml .= generateText("Power %", $textSize, $x, $y);

    $shapesXml .= generateRectangle($startX - $borderPadding, $startY - $borderPadding, $width, $height, 4, $LINE_INDEX);

    return $shapesXml;
}


sub generateAllSettings
{
    my $settingsXml;
    my $settingIndex = 3;
    for my $passCount(@passCounts)
    {
        for my $speed(@speeds)
        {
            $settingIndex++;
            my $name = "${speed}mm/s \@ $passCount pass" . ($passCount > 1 ? 'es' : '');
            $profiles{$speed}{$passCount} = $settingIndex;
            $settingsXml .= generateSetting($name, $type, $speed, $settingIndex, $passCount);
        }
    }
    die "Too many cut settings profiles ($settingIndex). Reduce the number of passes or speeds.\n" if $settingIndex > 30;
    return $settingsXml;
}


sub generateElipse
{
    my ($index, $scale, $radiusX, $radiusY, $x, $y) = @_;
    my $elipse = $elipseTemplate;
    $elipse =~ s/%%INDEX%%/$index/g;
    $elipse =~ s/%%SCALE%%/$scale/g;
    $elipse =~ s/%%RADIUS_X%%/$radiusX/g;
    $elipse =~ s/%%RADIUS_Y%%/$radiusY/g;
    $elipse =~ s/%%X%%/$x/g;
    $elipse =~ s/%%Y%%/$y/g;

    return $elipse;
}

sub generateRectangle
{
    my ($x, $y, $width, $height, $cornerRadius, $index) = @_;
    $x += $width / 2;
    $y += $height / 2;
    my $xml = <<EOT;
    <Shape Type="Rect" CutIndex="$index" W="$width" H="$height" Cr="$cornerRadius">
        <XForm>1 0 0 1 $x $y</XForm>
    </Shape>
EOT
    return $xml;
}



sub generateSetting
{
    my ($name, $type, $speed, $index, $passCount) = @_;

    my $min_power = 10;
    my $max1 = $maxSafePower;
    my $max2 = $maxSafePower;

    my $setting = $settingTemplate;
    $setting =~ s/%%TYPE%%/$type/;      #Cut, Scan, Scan+Cut
    $setting =~ s/%%INDEX%%/$index/g;
    $setting =~ s/%%NAME%%/$name/;
    $setting =~ s/%%MIN1%%/$min_power/; # main
    $setting =~ s/%%MAX1%%/$max1/;      # main
    $setting =~ s/%%MIN2%%/$min_power/; # Line when Scan+Cut
    $setting =~ s/%%MAX2%%/$max2/;      # Line when Scan+Cut
    $setting =~ s/%%SPEED%%/$speed/;
    $setting =~ s/%%PASSES%%/$passCount/;
    return $setting;
}

sub generateText
{
    my ($text, $height, $x, $y, $vertical) = @_;
    my $textXml = $textTemplate;

    $textXml =~ s/%%TEXT%%/$text/;
    $textXml =~ s/%%HEIGHT%%/$height/;
    $textXml =~ s/%%X%%/$x/;
    $textXml =~ s/%%Y%%/$y/;
    if ($vertical)
    {
        $textXml =~ s/%%M1%%/0/;
        $textXml =~ s/%%M2%%/-1/;
        $textXml =~ s/%%M3%%/1/;
        $textXml =~ s/%%M4%%/0/;
    }
    else
    {
        $textXml =~ s/%%M1%%/1/;
        $textXml =~ s/%%M2%%/0/;
        $textXml =~ s/%%M3%%/0/;
        $textXml =~ s/%%M4%%/1/;
    }

    return $textXml;
}


sub init
{
    $textTemplate = <<'EOT';
    <Shape Type="Text" CutIndex="$TEXT_INDEX" Font="Arial,-1,100,5,50,0,0,0,0,0" Str="%%TEXT%%" H="%%HEIGHT%%" LS="0" LnS="-25" Ah="1" Av="1" Weld="1" HasBackupPath="1">
            <XForm>%%M1%% %%M2%% %%M3%% %%M4%% %%X%% %%Y%%</XForm>
    </Shape>
EOT


    $elipseTemplate = <<'EOT';
    <Shape Type="Ellipse" CutIndex="%%INDEX%%" PowerScale="%%SCALE%%" Rx="%%RADIUS_X%%" Ry="%%RADIUS_Y%%">
        <XForm>1 0 0 1 %%X%% %%Y%%</XForm>
    </Shape>
EOT

    $settingTemplate = <<'EOT';
    <CutSetting type="%%TYPE%%">
        <index Value="%%INDEX%%"/>
        <name Value="%%NAME%%"/>
        <minPower Value="%%MIN1%%"/>
        <maxPower Value="%%MAX1%%"/>
        <minPower2 Value="%%MIN2%%"/>
        <maxPower2 Value="%%MAX2%%"/>
        <speed Value="%%SPEED%%"/>
        <priority Value="%%INDEX%%"/>
        <numPasses Value="%%PASSES%%"/>
        <perfLen Value="0.09906"/>
        <perfSkip Value="0.09906"/>
        <dotTime Value="1"/>
        <overscan Value="0"/>
        <floodFill Value="1"/>
        <interval Value="0.101"/>
    </CutSetting>
EOT

    $header = <<EOT;
<?xml version="1.0" encoding="UTF-8"?>
<LightBurnProject AppVersion="1.1.04" FormatVersion="1" MaterialHeight="0" MirrorX="True" MirrorY="True">
    <VariableText>
        <Start Value="0"/>
        <End Value="999"/>
        <Current Value="0"/>
        <Increment Value="1"/>
        <AutoAdvance Value="0"/>
    </VariableText>
    <UIPrefs>
        <Optimize_ByLayer Value="0"/>
        <Optimize_ByGroup Value="-1"/>
        <Optimize_ByPriority Value="1"/>
        <Optimize_WhichDirection Value="0"/>
        <Optimize_InnerToOuter Value="1"/>
        <Optimize_ByDirection Value="0"/>
        <Optimize_ReduceTravel Value="1"/>
        <Optimize_HideBacklash Value="0"/>
        <Optimize_ReduceDirChanges Value="0"/>
        <Optimize_ChooseCorners Value="0"/>
        <Optimize_AllowReverse Value="1"/>
        <Optimize_RemoveOverlaps Value="0"/>
        <Optimize_OptimalEntryPoint Value="1"/>
    </UIPrefs>
    <CutSetting type="$SCAN">
        <index Value="$TEXT_INDEX"/>
        <name Value="Text"/>
        <minPower Value="10"/>
        <maxPower Value="10"/>
        <minPower2 Value="10"/>
        <maxPower2 Value="10"/>
        <speed Value="20"/>
        <priority Value="$TEXT_INDEX"/>
        <perfLen Value="0.09906"/>
        <perfSkip Value="0.09906"/>
        <dotTime Value="1"/>
        <tabCount Value="1"/>
        <tabCountMax Value="1"/>
        <tabSpacing Value="50.04"/>
        <overscan Value="0"/>
        <floodFill Value="1"/>
        <interval Value="0.101"/>
    </CutSetting>
    <CutSetting type="$CUT">
        <index Value="$LINE_INDEX"/>
        <name Value="Line"/>
        <minPower Value="10"/>
        <maxPower Value="10"/>
        <minPower2 Value="10"/>
        <maxPower2 Value="20"/>
        <speed Value="20"/>
        <priority Value="$LINE_INDEX"/>
        <perfLen Value="0.09906"/>
        <perfSkip Value="0.09906"/>
        <dotTime Value="1"/>
        <tabCount Value="1"/>
        <tabCountMax Value="1"/>
        <tabSpacing Value="50.04"/>
        <overscan Value="0"/>
        <floodFill Value="1"/>
        <interval Value="0.101"/>
    </CutSetting>
    <CutSetting type="$CUT">
        <index Value="$CUT_INDEX"/>
        <name Value="Cut"/>
        <minPower Value="15"/>
        <maxPower Value="15"/>
        <minPower2 Value="10"/>
        <maxPower2 Value="10"/>
        <speed Value="10"/>
        <priority Value="99"/>
        <numPasses Value="1"/>
        <perfLen Value="0.09906"/>
        <perfSkip Value="0.09906"/>
        <dotTime Value="1"/>
        <tabCount Value="1"/>
        <tabCountMax Value="1"/>
        <overscan Value="0"/>
        <floodFill Value="1"/>
        <interval Value="0.101"/>
    </CutSetting>


EOT

    $footer = <<'EOT';
    <Notes ShowOnLoad="0" Notes=""/>
</LightBurnProject>
EOT

}