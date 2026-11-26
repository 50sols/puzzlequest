<?php
namespace App\Services;
final class SafeZip {
    public function extract(string $archive,string $destination,int $maxFiles=25000,int $maxBytes=1073741824): array {
        $zip=new \ZipArchive();if($zip->open($archive)!==true)throw new \RuntimeException('Invalid ZIP');$names=[];$total=0;$seen=[];
        try{if($zip->numFiles>$maxFiles)throw new \RuntimeException('ZIP has too many entries');
            for($i=0;$i<$zip->numFiles;$i++){$stat=$zip->statIndex($i);$name=$stat['name'];$this->path($name);if(isset($seen[strtolower($name)]))throw new \RuntimeException('Duplicate/case-conflicting ZIP entry');$seen[strtolower($name)]=true;
                $opsys=0;$attrs=0;$zip->getExternalAttributesIndex($i,$opsys,$attrs);if((($attrs>>16)&0170000)===0120000)throw new \RuntimeException('ZIP symbolic links are forbidden');
                $total+=$stat['size'];if($total>$maxBytes||($stat['size']>1048576&&$stat['size']/max(1,$stat['comp_size'])>300))throw new \RuntimeException('ZIP expansion limit exceeded');$names[]=$name;
            }
            if(!is_dir($destination)&&!mkdir($destination,0750,true))throw new \RuntimeException('Cannot create staging directory');$base=realpath($destination);
            foreach($names as$name){$target=$destination.DIRECTORY_SEPARATOR.str_replace('/',DIRECTORY_SEPARATOR,$name);$parent=dirname($target);if(!is_dir($parent)&&!mkdir($parent,0750,true))throw new \RuntimeException('Cannot create staging subdirectory');$real=realpath($parent);if($real!==$base&&!str_starts_with($real,$base.DIRECTORY_SEPARATOR))throw new \RuntimeException('Extraction escaped staging');
                if(str_ends_with($name,'/')){if(!is_dir($target))mkdir($target,0750,true);continue;}
                $input=$zip->getStream($name);$output=fopen($target,'xb');if(!$input||!$output)throw new \RuntimeException('Cannot extract entry');$copied=stream_copy_to_stream($input,$output);fclose($input);fclose($output);if($copied!==$zip->statName($name)['size'])throw new \RuntimeException('Truncated ZIP entry');chmod($target,0640);
            }
        }finally{$zip->close();}
        return $names;
    }
    public function path(string $name): void {if($name===''||str_contains($name,"\0")||str_contains($name,'\\')||str_contains($name,':')||str_starts_with($name,'/')||preg_match('~(^|/)\.\.?(/|$)~',$name)||preg_match('/[\x00-\x1f]/',$name))throw new \RuntimeException('Unsafe archive path');}
}
