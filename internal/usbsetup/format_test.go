package usbsetup

import (
	"context"
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestElevatedFormatResults(t *testing.T) {
	for _, tc := range []struct {
		name           string
		child, process error
		want           string
	}{
		{"success", nil, nil, ""},
		{"partial-format", errors.New("Format-Volume failed after Clear-Disk"), errors.New("exit 1"), "Format-Volume failed after Clear-Disk"},
		{"cancelled", nil, context.Canceled, "cancelled"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			dir := t.TempDir()
			saveFormatResult(filepath.Join(dir, "job.json"), tc.child)
			err := readFormatResult(dir, tc.process)
			if tc.want == "" && err != nil || tc.want != "" && (err == nil || !strings.Contains(err.Error(), tc.want)) {
				t.Fatalf("result: %v", err)
			}
		})
	}
	for _, content := range []string{"", "not json", strings.Repeat("x", 4097), `{"success":false}`} {
		dir := t.TempDir()
		if content != "" {
			if err := os.WriteFile(filepath.Join(dir, "result.json"), []byte(content), 0600); err != nil {
				t.Fatal(err)
			}
		}
		if readFormatResult(dir, nil) == nil {
			t.Fatal("missing/invalid result treated as success")
		}
		if err := readFormatResult(dir, context.DeadlineExceeded); !errors.Is(err, context.DeadlineExceeded) {
			t.Fatal(err)
		}
	}
}

func TestFormatResultIsBoundedAndExclusive(t *testing.T) {
	dir := t.TempDir()
	job := filepath.Join(dir, "job.json")
	saveFormatResult(job, errors.New(strings.Repeat("\x00", 10000)))
	data, err := os.ReadFile(filepath.Join(dir, "result.json"))
	if err != nil || len(data) > 4096 {
		t.Fatal(len(data), err)
	}
	saveFormatResult(job, nil)
	after, _ := os.ReadFile(filepath.Join(dir, "result.json"))
	if string(after) != string(data) {
		t.Fatal("overwrote an existing result")
	}
}

// Execute the production script with storage cmdlets shadowed by mocks. These
// tests never invoke a real storage cmdlet, elevate, or access a physical drive.
func TestWindowsFormatScriptExecution(t *testing.T) {
	shell, err := exec.LookPath("pwsh")
	if err != nil {
		shell, err = exec.LookPath("powershell.exe")
	}
	if err != nil {
		t.Skip("PowerShell required; executed by the Windows CI job")
	}
	for _, tc := range []struct {
		style, fail, want string
	}{
		{"RAW", "", "clear,initialize,partition,format"},
		{"MBR", "", "clear,partition,format"},
		{"GPT", "", "clear,convert,partition,format"},
		{"MBR", "format", "clear,partition,format"},
		{"MBR", "identity", ""},
	} {
		t.Run(tc.style+"-"+tc.fail, func(t *testing.T) {
			p, err := LoadPackage(fixtureZip(t, fixtureFiles()))
			if err != nil {
				t.Fatal(err)
			}
			d := Drive{ID: "fixture", Fingerprint: "identity", Device: "4", Serial: "USB123", Size: 16 << 30}
			ready := d
			ready.Eligible, ready.Mount = true, t.TempDir()
			mock := `$script:calls=[System.Collections.Generic.List[string]]::new()
function Get-Disk { param($Number) [pscustomobject]@{BusType='USB';IsBoot=$false;IsSystem=$false;IsReadOnly=$false;Size=17179869184;SerialNumber='USB123';PartitionStyle='` + tc.style + `'} }
function Clear-Disk { param([Parameter(ValueFromPipeline=$true)]$InputObject,[switch]$RemoveData,[switch]$RemoveOEM,$Confirm) $script:calls.Add('clear') }
function Initialize-Disk { param($Number,$PartitionStyle) $script:calls.Add('initialize'); if('` + tc.style + `' -ne 'RAW'){throw 'already initialized'} }
function Set-Disk { param($Number,$PartitionStyle) $script:calls.Add('convert') }
function New-Partition { param($DiskNumber,[switch]$UseMaximumSize,$Size,[switch]$AssignDriveLetter) $script:calls.Add('partition'); [pscustomobject]@{Mock=$true} }
function Format-Volume { param([Parameter(ValueFromPipeline=$true)]$InputObject,$FileSystem,$NewFileSystemLabel,$Confirm) $script:calls.Add('format'); if('` + tc.fail + `' -eq 'format'){throw 'mock formatting failure'} }
`
			if tc.fail == "identity" {
				d.Serial = "different"
			}
			var calls string
			run := func(ctx context.Context, _ string, args []string, _ string) ([]byte, error) {
				out, err := exec.CommandContext(ctx, shell, "-NoProfile", "-NonInteractive", "-Command", mock+"\ntry {\n"+args[len(args)-1]+"\n} catch { Write-Output $_.Exception.Message; exit 1 } finally { Write-Output ('CALLS='+($script:calls -join ',')) }").CombinedOutput()
				for _, line := range strings.Split(strings.ReplaceAll(string(out), "\r", ""), "\n") {
					if strings.HasPrefix(line, "CALLS=") {
						calls = strings.TrimPrefix(line, "CALLS=")
					}
				}
				if err != nil {
					return nil, errors.New(string(out))
				}
				return out, nil
			}
			err = nativeFormat(context.Background(), d, p, testConfig, "windows", run, func(context.Context) ([]Drive, error) { return []Drive{ready}, nil })
			if calls != tc.want || (err != nil) != (tc.fail != "") {
				t.Fatalf("calls=%q, err=%v", calls, err)
			}
			if tc.fail != "" {
				if _, err := os.Stat(filepath.Join(ready.Mount, entry)); !os.IsNotExist(err) {
					t.Fatal("activated a failed preparation")
				}
			}
		})
	}
}
